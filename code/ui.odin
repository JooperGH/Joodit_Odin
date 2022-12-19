package main

import "core:mem"
import "core:fmt"
import "core:math"
import "core:log"

UI_ID :: distinct u32

UI_Widgets :: struct {
    all: map[UI_ID]^UI_Widget,
    parents: [dynamic]^UI_Widget,
    fl_adds: [dynamic]UI_Widget_Flags,
    fl_rems: [dynamic]UI_Widget_Flags,

    root: ^UI_Widget,
    first: ^UI_Widget,
    last: ^UI_Widget,

    id_null: UI_ID,
    id_hot: UI_ID,
    id_active: UI_ID,
}

UI_State :: struct {
    app: ^App,
    allocator: mem.Allocator,
    temp_allocator: mem.Allocator,

    font_size: f32,
    font_atlas: ^Font_Atlas,
    font: ^Font,

    // Input
    events: [dynamic]^Event,
    text: [dynamic]rune,

    keys:    [Key_Code.Last]Key_Data,
    buttons: [Button_Code.Last]Key_Data,
    mods:    [Mod_Code.Last]Key_Data,
    mods_set: bit_set[Mod_Code],

    last_valid_mouse_pos: Vec2,
    mouse_pos: Vec2,
    prev_mouse_pos: Vec2,
    mouse_dpos: Vec2,
    scroll_pos: Vec2,
    
    window_size: Vec2,
    focused: b32,
    axis_toggle: b32,

    // UI

    widgets: UI_Widgets,

    dcl: ^Draw_Cmd_List,
}

ui := UI_State{}

ui_init_widgets :: proc() {
    ui.widgets.all = make(map[UI_ID]^UI_Widget, 128, ui.allocator)
    ui.widgets.parents = make([dynamic]^UI_Widget, 0, 10, ui.allocator)
    ui.widgets.fl_adds = make([dynamic]UI_Widget_Flags, 0, 10, ui.allocator)
    ui.widgets.fl_rems = make([dynamic]UI_Widget_Flags, 0, 10, ui.allocator)

    ui.widgets.id_null, _ = ui_get_id("")
    ui.widgets.id_hot = ui.widgets.id_null
    ui.widgets.id_active = ui.widgets.id_null
    
    ui.widgets.first = nil
    ui.widgets.last = nil
}

ui_init :: proc(app: ^App) {
    ui.app = app

    ui.window_size = app.window_size

    arena := new(mem.Arena)
    mem.arena_init(arena, make([]byte, 2*mem.Megabyte))
    ui.temp_allocator = mem.arena_allocator(arena)
    
    arena = new(mem.Arena)
    mem.arena_init(arena, make([]byte, 1*mem.Megabyte))
    ui.allocator = mem.arena_allocator(arena)
    
    ui_init_input()

    ui.font_size = 32.0
    ui.font_atlas = font_atlas_create()
    ui.font = font_atlas_add_font_from_ttf(ui.font_atlas, app, "fonts/OpenSans-Regular.ttf", 30.0)
    ui.font.configs[0].oversample_x = 2
    ui.font.configs[0].oversample_y = 2
    font_atlas_build(ui.font_atlas)
    ui.dcl = draw_new_draw_list()
    
    ui_init_widgets()
}

ui_begin :: proc() {
    ui.window_size = ui.app.window_size
    
    mem.free_all(ui.temp_allocator)
    ui_update_input_events()

    assert(len(ui.widgets.parents) == 0)
    assert(len(ui.widgets.fl_adds) == 0)
    assert(len(ui.widgets.fl_rems) == 0)
    
    ui.widgets.first = nil
    ui.widgets.last = nil

    ui.widgets.root = ui_widget({.DrawBackground}, "__ROOT__")
    ui.widgets.root.size[.X] = ui_widget_size(.Pixels, ui.window_size.x)
    ui.widgets.root.size[.Y] = ui_widget_size(.Pixels, ui.window_size.y)
    ui.widgets.root.style.gradient = false
    ui.widgets.root.style.colors[.Bg] = {0.1, 0.1, 0.1, 1.0}
    ui_push_parent(ui.widgets.root)
}

ui_widget_size_deterministic_pass :: proc() {
    for w := ui.widgets.first; w != nil; w = w.hash_next {
        if ui_widget_is_row(w) do continue

        text_size := (w.size[.X].kind == .Text || w.size[.Y].kind == .Text) ? calc_text_size(ui.font, w.str, ui.font_size) : Vec2{0, 0}
        for size, axis in w.size {
            calc_size := &w.calc_size[axis]
            if size.kind == .Pixels {
                calc_size^ = size.value
            } else if size.kind == .Text {
                calc_size^ = text_size[axis] * size.value
            }
        }
    }
}

ui_widget_size_percent_parent_pass :: proc() {
    for w := ui.widgets.first; w != nil; w = w.hash_next {
        if ui_widget_is_row(w) do continue

        for size, axis in w.size {
            calc_size := &w.calc_size[axis]
            if size.kind == .PercentParent {
                calc_size^ = w.parent.calc_size[axis] * size.value
            }
        }
    }
}

ui_widget_size_auto_pass :: proc() {
    autos := make([dynamic]^UI_Widget, ui.temp_allocator)
    autos_counts := make([dynamic]Vec2, ui.temp_allocator)
    autos_sizes := make([dynamic]Vec2, ui.temp_allocator)

    for w := ui.widgets.first; w != nil; w = w.hash_next {
        if ui_widget_is_row(w) do continue

        auto_sibling_count, sibling_size: Vec2
        for size, axis in w.size {
            if size.kind == .Auto {
                auto_sibling_count[axis] += 1
                found_head, found_tail := false, false
                for s := w.prev; s != nil; s = s.prev {
                    if ui_widget_is_row(s) && s.parent == w.parent {
                        found_head = true
                        break
                    }
                    if s.size[axis].kind == .Auto do auto_sibling_count[axis] += 1
                    sibling_size[axis] += s.calc_size[axis]
                }
                for s := w.next; s != nil; s = s.next {
                    if ui_widget_is_row(s) && s.parent == w.parent {
                        found_tail = true
                        break
                    }
                    if s.size[axis].kind == .Auto do auto_sibling_count[axis] += 1
                    sibling_size[axis] += s.calc_size[axis]
                }
                assert(found_head == found_tail)
            }
        }

        if ui_size_is_kind(w, UI_Size_Kind.Auto) {
            append(&autos, w)
            append(&autos_counts, auto_sibling_count)
            append(&autos_sizes, sibling_size)
        }
    }

    for w, i in autos {
        for size, axis in w.size {
            if autos_counts[i][axis] > 0.0 {
                calc_size := &w.calc_size[axis]
                calc_size^ = ((w.parent.layout.next[u32(axis)*2]-w.parent.layout.next[u32(axis)])-autos_sizes[i][axis])/autos_counts[i][axis]
            }
        }
    }
}

ui_end :: proc() {
    ui_pop_parent()

    assert(len(ui.widgets.parents) == 0)
    assert(len(ui.widgets.fl_adds) == 0)
    assert(len(ui.widgets.fl_rems) == 0)

    assert(ui.widgets.first != nil)
    assert(ui.widgets.first == ui.widgets.root)

    for w := ui.widgets.first; w != nil; w = w.hash_next {
        if w.first != nil {
            ui_widget_new_layout(w)
        }
    }
    
    ui_widget_size_deterministic_pass()
    ui_widget_size_percent_parent_pass()
    ui_widget_size_auto_pass()

    for w := ui.widgets.first; w != nil; w = w.hash_next {
        if w.first != nil {
            ui_widget_new_layout(w)
        }

        if ui_widget_is_row(w) {
            if w.parent.layout.axis == .X {
                // Changing to Y
                row_head : ^UI_Widget = nil
                for s := w.hash_prev; s != nil; s = s.prev {
                    if ui_widget_is_row(s) && s.parent.id == w.parent.id {
                        row_head = s
                        break
                    }
                }

                max_size_y : f32 = 0.0
                for s := w.hash_prev; s != row_head; s = s.prev {
                    if !ui_widget_is_row(s) {
                        max_size_y = max(max_size_y, s.calc_size.y)
                    }
                }

                w.parent.layout.next.y += max_size_y
                w.parent.layout.next.x = w.parent.rect.x
            } else {
                w.parent.layout.next.x = w.parent.rect.x
            }

            w.parent.layout.axis = (w.parent.layout.axis == .X ? .Y : .X)
            continue
        }

        is_spacer := ui_widget_is_spacer(w)

        if w.first != nil {
            if w.parent == nil {
                w.rect = {
                    0, 
                    0, 
                    w.calc_size.x, 
                    w.calc_size.y,
                }
            } else {
                w.rect = {
                    w.parent.layout.next.x,
                    w.parent.layout.next.y,
                    w.parent.layout.next.x + w.calc_size.x,
                    w.parent.layout.next.y + w.calc_size.y,
                }    
                
                w.parent.layout.next.x = w.parent.layout.axis == .X ? w.parent.layout.next.x + w.calc_size.x :  w.parent.layout.next.x
                w.parent.layout.next.y = w.parent.layout.axis == .Y ? w.parent.layout.next.y + w.calc_size.y :  w.parent.layout.next.y
            }
                
            w.layout.next = {
                w.rect.x,
                w.rect.y,
                w.rect.x + w.calc_size.x,
                w.rect.x + w.calc_size.y,
            }
        } else {
            w.rect = {
                w.parent.layout.next.x,
                w.parent.layout.next.y,
                w.parent.layout.next.x + w.calc_size.x,
                w.parent.layout.next.y + w.calc_size.y,
            }

            if is_spacer {
                if w.parent.layout.axis == .X {
                    w.parent.layout.next.x = w.parent.layout.next.x + w.calc_size.x
                } else if w.parent.layout.axis == .Y {
                    w.parent.layout.next.y = w.parent.layout.next.y + w.calc_size.y
                }
            } else {
                w.parent.layout.next.x = w.parent.layout.axis == .X ? w.parent.layout.next.x + w.calc_size.x :  w.parent.layout.next.x
                w.parent.layout.next.y = w.parent.layout.axis == .Y ? w.parent.layout.next.y + w.calc_size.y :  w.parent.layout.next.y
            }
        }
    }

    for w := ui.widgets.first; w != nil; w = w.hash_next {
        if .Ignore in w.flags do continue

        if .DrawBackground in w.flags {
            anim := 0.5*(ui_widget_hot_anim(w) + ui_widget_active_anim(w))
            border_size : f32 = .DrawBorder in w.flags ? anim * w.style.border_size : 0.0
            roundness := w.style.rounding
            softness : f32 = 1.0
            border_color := w.style.colors[.Border]
            if w.style.gradient {
                colors := [2]Color{
                    w.style.colors[.BgGradient0],
                    w.style.colors[.BgGradient1],
                }
                draw_add_rect(ui.dcl, w.rect, roundness, border_size, {colors[0], colors[0], colors[1], colors[1]}, border_color) 
            } else {
                color := w.style.colors[.Bg]
                draw_add_rect(ui.dcl, w.rect, roundness, border_size, color, border_color)
            }
        }
        
		if .DrawText in w.flags {
            anim := .TextAnimation in w.flags ? ui_widget_anim(w, 0.5) : 0.0
            color := anim*Color{1.0, 1.0, 0.0, 1.0}+(1.0-anim)*Color{1, 1, 1, 1}

            text_pos := w.rect.xw
            if .TextCenterX in w.flags || .TextCenterY in w.flags {
                text_size := calc_text_size(ui.font, w.str, ui.font_size)
                rect_size := rect_dim(w.rect)
    
                offset := 0.5*(rect_size-text_size)
    
                if .TextCenterX in w.flags {
                    text_pos.x += offset.x
                } 
                if .TextCenterY in w.flags {
                    text_pos.y -= offset.y
                } 
            }
            draw_add_text(ui.dcl, ui.font, w.str, ui.font_size, text_pos, color)
		}
    }

    ui.widgets.id_hot = ui.widgets.id_null
    ui.widgets.id_active = ui.widgets.id_null
    
    for w := ui.widgets.last; w != nil; w = w.hash_prev {
        if .Ignore not_in w.flags {
            w.i = ui_widget_interaction(w)
        
            if ui.widgets.id_hot == ui.widgets.id_null && (w.hot_condition != nil ? w->hot_condition() : w.i.hovered)  {
                ui_set_as_hot(w)
            }
    
            if ui.widgets.id_active == ui.widgets.id_null && (.Draggable in w.flags ? true : ui_match_hot(w)) && (w.active_condition != nil ? w->active_condition() : false) {
                ui_set_as_active(w)
            }
        }

        w.parent = nil
        w.first = nil
        w.last = nil
        w.next = nil
        w.prev = nil
        w.offset = {}
        w.calc_size = {}
        w.layout = nil

        w.hot_t -= 2.0*ui.app.dt
        w.active_t -= 2.0*ui.app.dt
        if w.hot_t <= 0.0 do w.hot_t = 0.0
        if w.active_t <= 0.0 do w.active_t = 0.0
    }

    /*
    // Layout - Step 1
    for w in ui.widgets {
        text_size := (w.size[.X].kind == .Text || w.size[.Y].kind == .Text) ? calc_text_size(ui.font, w.str, ui.font_size) : Vec2{0, 0}
        for size, axis in w.size {
            calc_size := &w.calc_size[axis]
            if size.kind == .Pixels {
                calc_size^ = size.value
            } else if size.kind == .Text {
                calc_size^ = text_size[axis] * size.value
            }
        }
    }

    // Layout - Step 2
    for w in ui.widgets {
        for size, axis in w.size {
            calc_size := &w.calc_size[axis]
            if size.kind == .PercentParent {
                calc_size^ = w.parent.calc_size[axis] * size.value
            }
        }
    }

    for w in ui.widgets {
        for size, axis in w.size {
            calc_size := &w.calc_size[axis]
            if size.kind == .MinSibling {
                calc_size^ = 0
                for prev := w.prev; prev != nil; prev = prev.prev {
                    calc_size^ += prev.calc_size[axis]
                }
                for next := w.next; next != nil; next = next.next {
                    calc_size^ += next.calc_size[axis]
                }
                calc_size^ = w.parent.calc_size[axis] - calc_size^ 
            } else if size.kind == .MaxSibling {
                calc_size^ = 0
                for next := w.parent.first; next != nil; next = next.next {
                    calc_size^ = max(calc_size^, next.calc_size[axis])
                }
            }
        }
    }

    // Layout - Step 2
    for w in ui.widgets {
        for size, axis in w.size {
            calc_size := &w.calc_size[axis]
            if size.kind == .PercentParent {
                calc_size^ = w.parent.calc_size[axis] * size.value
            }
        }
    }

    for wi := len(ui.widgets)-1; wi >= 0; wi -= 1 {
        w := ui.widgets[wi]
        for size, axis in w.size {
            calc_size := &w.calc_size[axis]
            if size.kind == .SumChildren {
                calc_size^ = 0
                for child := w.first; child != nil; child = child.next {
                    if size.kind == .SumChildren do calc_size^ += child.calc_size[axis]
                    w.sum_children[axis] += child.calc_size[axis]
                }
            } else if size.kind == .MaxChildren {
                calc_size^ = 0
                for child := w.first; child != nil; child = child.next {
                    calc_size^ = max(calc_size^, child.calc_size[axis])
                }
            }
        }
    }

    for w in ui.widgets {
        axis : UI_Axis = .FillX in w.flags ? .X : .FillY in w.flags ? .Y : .X
        w.offset[axis] = (w.prev != nil ? w.prev.offset[axis] + w.prev.calc_size[axis] : 0.0) 
        
        if w.parent == nil {
            w.rect = {
                w.offset.x, 
                w.offset.y,
                w.offset.x + w.calc_size.x,
                w.offset.y + w.calc_size.y,
            }
        } else {
            w.rect = {
                w.parent.rect.x + w.offset.x,
                w.parent.rect.y + w.offset.y,
                w.rect.x + w.calc_size.x,
                w.rect.y + w.calc_size.y,
            }
        }
    }
    /*
    // Can optimize this
    ui_widget_descending_loop(ui.root, nil, proc(w: ^UI_Widget, data: rawptr) {
        if w.parent == nil do return
        
        is_leftover_x_or_y := ui_size_is_kind(w, UI_Size_Kind.LeftoverChildSum)
        if !is_leftover_x_or_y {
            return
        }

        num_leftovers_x, num_leftovers_y: i32
        total_size_x, total_size_y: f32
        sentinel := w.parent.first
        for sentinel != nil {
            if !ui_size_is_kind(sentinel, UI_Size_Kind.LeftoverChildSum) {
                total_size_x += sentinel.calc_size.x
                total_size_y += sentinel.calc_size.y
            } else {
                if ui_size_is_kind(sentinel, UI_Axis.X, UI_Size_Kind.LeftoverChildSum) {
                    num_leftovers_x += 1
                }
                if ui_size_is_kind(sentinel, UI_Axis.Y, UI_Size_Kind.LeftoverChildSum) {
                    num_leftovers_y += 1 
                }
            }
            sentinel = sentinel.next
        }

        if ui_size_is_kind(w, UI_Axis.X, UI_Size_Kind.LeftoverChildSum) {
            w.calc_size.x = (w.parent.calc_size.x - total_size_x)*(w.size[.X].value != 0.0 ? w.size[.X].value : (1.0/f32(num_leftovers_x)))
        }

        if ui_size_is_kind(w, UI_Axis.Y, UI_Size_Kind.LeftoverChildSum) {
            w.calc_size.y = (w.parent.calc_size.y - total_size_y)*(w.size[.Y].value != 0.0 ? w.size[.Y].value : (1.0/f32(num_leftovers_y)))
        }
    })

    // FillX, FillY Loop
    ui_widget_descending_loop(ui.root, nil, proc(w: ^UI_Widget, data: rawptr) {
        if w.first != nil {
            parent_pad := ui_widget_calc_pad(w)

            no_fill_y_sizes := make([dynamic]f32, ui.temp_allocator)
            no_fill_x_sizes := make([dynamic]f32, ui.temp_allocator)
             
            total_size_x, total_size_y: f32 = 0, 0
            sentinel := w.first
            for sentinel != nil {
                if .FillY not_in sentinel.flags {
                    total_size_x += sentinel.calc_size.x + parent_pad.x
                } else if !(ui_size_is_kind(sentinel, UI_Axis.X, UI_Size_Kind.LeftoverChildSum) && ui_match_null(sentinel)) {
                    append(&no_fill_x_sizes, sentinel.calc_size.x + parent_pad.x)
                }

                if .FillX not_in sentinel.flags {
                    total_size_y += sentinel.calc_size.y + parent_pad.y
                } else if !(ui_size_is_kind(sentinel, UI_Axis.Y, UI_Size_Kind.LeftoverChildSum) && ui_match_null(sentinel)) {
                    append(&no_fill_y_sizes, sentinel.calc_size.y + parent_pad.y)
                }

                sentinel = sentinel.next
            }

            if total_size_y > w.calc_size.y || len(no_fill_y_sizes) > 0 {
                // Fix x sizes
                // Priority is removing size from spacers

                required_size_reduction := total_size_y - w.calc_size.y

                total_other_count: i32 = 0
                total_other_size_y: f32 = 0.0
                total_spacer_count: i32 = 0
                total_spacer_size_y: f32 = 0.0
                sentinel = w.first
                for sentinel != nil {
                    if ui_size_is_kind(sentinel, UI_Axis.Y, UI_Size_Kind.LeftoverChildSum) && ui_match_null(sentinel) {
                        total_spacer_size_y += sentinel.calc_size.y
                        total_spacer_count += 1
                    } else {
                        total_other_size_y += sentinel.calc_size.y
                        total_other_count += 1
                    }
                    sentinel = sentinel.next
                }

                if total_spacer_count > 0 {
                    if total_spacer_size_y >= required_size_reduction {
                        
                        sentinel = w.first
                        for sentinel != nil {
                            if ui_size_is_kind(sentinel, UI_Axis.Y, UI_Size_Kind.LeftoverChildSum) && ui_match_null(sentinel) {
                                sentinel.calc_size.y -= required_size_reduction/f32(total_spacer_count)
                            }
                            sentinel = sentinel.next
                        }
                    }
                } else {
                    if total_other_count > 0 {
                        sentinel = w.first
                        k := 0
                        for sentinel != nil {
                            if .FillY not_in sentinel.flags {
                                sentinel.calc_size.y -= no_fill_y_sizes[k] - w.calc_size.y
                                k += 1
                            } else {
                                sentinel.calc_size.y -= required_size_reduction/f32(total_other_count)
                            }
                            sentinel = sentinel.next
                        }
                    }
                }
            }
            
            if total_size_x > w.calc_size.x || len(no_fill_x_sizes) > 0 {
                // Fix x sizes
                // Priority is removing size from spacers
    
                required_size_reduction := total_size_x - w.calc_size.x// + parent_pad.x
    
                total_other_count: i32 = 0
                total_other_size_x: f32 = 0.0
                total_spacer_count: i32 = 0
                total_spacer_size_x: f32 = 0.0
                sentinel = w.first
                for sentinel != nil {
                    if  ui_size_is_kind(sentinel, UI_Axis.X, UI_Size_Kind.LeftoverChildSum) && ui_match_null(sentinel) {
                        total_spacer_size_x += sentinel.calc_size.x
                        total_spacer_count += 1
                    } else {
                        total_other_size_x += sentinel.calc_size.x
                        total_other_count += 1
                    }
                    sentinel = sentinel.next
                }
    
                if total_spacer_count > 0 {
                    if total_spacer_size_x >= required_size_reduction {
                        sentinel = w.first
                        for sentinel != nil {
                            if ui_size_is_kind(sentinel, UI_Axis.X, UI_Size_Kind.LeftoverChildSum) && ui_match_null(sentinel) {
                                sentinel.calc_size.x -= required_size_reduction/f32(total_spacer_count)
                            }
                            sentinel = sentinel.next
                        }
                    }
                } else {
                    if total_other_count > 0 {
                        sentinel = w.first
                        k := 0
                        for sentinel != nil {
                            if .FillX not_in sentinel.flags {
                                sentinel.calc_size.x -= no_fill_x_sizes[k] - w.calc_size.x
                                k += 1
                            } else {
                                sentinel.calc_size.x -= required_size_reduction/f32(total_other_count)
                            }
                            sentinel = sentinel.next
                        }
                    }
                }
            }
        }
    })

    ui_widget_descending_loop(ui.root, nil, proc(w: ^UI_Widget, data: rawptr) {
        if w.parent == nil do return

        parent := w.parent

        pad := ui_widget_calc_pad(parent)

        w.calc_pos.x = parent.available_rect.x + 0.5*pad.x + w.offset.x
        w.calc_pos.y = parent.available_rect.y + 0.5*pad.y + w.offset.y

        if .FillY in w.flags do parent.available_rect.y += w.calc_size.y + pad.y
        if .FillX in w.flags do parent.available_rect.x += w.calc_size.x + pad.x

        w.rect = rect_from_pos_dim(w.calc_pos, w.calc_size)
        w.available_rect = w.rect
    })
    //ui_widget_descending_loop(ui.root, proc(w: ^UI_Widget) {
    //    if w.parent == nil {
    //        
    //        return
    //    } 
    //
    //    w.size = ui_layout_calc_size(w)
    //    ui_layout_calc_pos(w)
    //    w.rect = rect_from_pos_dim(w.pos, w.size) 
    //    w.available_rect = w.rect
    //})
    */
    */
    /*
    for _, w in &ui.widgets.all {
        if .Ignore in w.flags {
            return
        }

        pad_anim_factor : f32 = 5.0*0.5*(ui_widget_hot_anim(w) + ui_widget_active_anim(w))
        pad_anim_pad := Vec2{
            pad_anim_factor,
            pad_anim_factor,
        }
        if .DrawBackground in w.flags {
            bg_anim := 1.0 + 0.5*(ui_widget_hot_anim(w) + ui_widget_active_anim(w))
            border_size : f32 = .DrawBorder in w.flags ? w.style.border_size : 0.0
            roundness := w.style.rounding
            softness : f32 = 1.0
            border_color := w.style.colors[.Border]
            if w.style.gradient {
                colors := [2]Color{
                    bg_anim * w.style.colors[.BgGradient0],
                    bg_anim * w.style.colors[.BgGradient1],
                }
                draw_add_rect(ui.dcl, rect_grow(w.rect, pad_anim_pad), roundness, border_size, {colors[0], colors[0], colors[1], colors[1]}, border_color) 
            } else {
                color := bg_anim * w.style.colors[.Bg]
                draw_add_rect(ui.dcl, rect_grow(w.rect, pad_anim_pad), roundness, border_size, color, border_color)
            }
		}

		if .DrawText in w.flags {
            anim := .TextAnimation in w.flags ? ui_widget_anim(w, 0.5) : 0.0
            color := anim*Color{1.0, 1.0, 0.0, 1.0}+(1.0-anim)*Color{1, 1, 1, 1}

            text_pos := w.rect.xw
            if .CenterX in w.flags || .CenterY in w.flags {
                text_size := calc_text_size(ui.font, w.str, ui.font_size)
                rect_size := rect_dim(w.rect)
    
                offset := 0.5*(rect_size-text_size)
    
                if .CenterX in w.flags {
                    text_pos.x += offset.x
                } 
                if .CenterY in w.flags {
                    text_pos.y -= offset.y
                } 
            }
            draw_add_text(ui.dcl, ui.font, w.str, ui.font_size, text_pos, color)
		}
    }

    */
}

ui_free :: proc() {
    font_atlas_free(&ui.font_atlas)

    delete(ui.events)
    delete(ui.text)
}
