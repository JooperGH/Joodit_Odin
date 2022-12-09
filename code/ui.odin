package main

import "core:mem"
import "core:fmt"
import "core:math"
import "core:log"

UI_ID :: distinct u32

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

    // UI
    widget_count: u32,
    hash: []UI_Widget,
    root: ^UI_Widget,
    parent_stack: [dynamic]^UI_Widget,
    flag_add_stack: [dynamic]UI_Widget_Flags,
    flag_rem_stack: [dynamic]UI_Widget_Flags,
    
    null: UI_ID,
    hot: UI_ID,
    active: UI_ID,

    dcl: ^Draw_Cmd_List,
}

ui := UI_State{}

ui_init :: proc(app: ^App) {
    ui.app = app

    ui.window_size = app.window_size

    arena := new(mem.Arena)
    mem.arena_init(arena, make([]byte, 2*mem.Megabyte))
    ui.temp_allocator = mem.arena_allocator(arena)
    
    arena = new(mem.Arena)
    mem.arena_init(arena, make([]byte, 1*mem.Megabyte))
    ui.allocator = mem.arena_allocator(arena)

    ui.hash = make([]UI_Widget, 8192)
    ui.root = ui_widget_create_root("_ROOT_")
    ui.parent_stack = make([dynamic]^UI_Widget, 0, 10)
    ui.flag_add_stack = make([dynamic]UI_Widget_Flags, 0, 10)
    ui.flag_rem_stack = make([dynamic]UI_Widget_Flags, 0, 10)

    ui.null, _ = ui_get_id("")
    ui.hot = ui.null
    ui.active = ui.null

    ui.font_size = 32.0
    ui.font_atlas = font_atlas_create()
    ui.font = font_atlas_add_font_from_ttf(ui.font_atlas, app, "fonts/OpenSans-Regular.ttf", 30.0)
    ui.font.configs[0].oversample_x = 2
    ui.font.configs[0].oversample_y = 2
    font_atlas_build(ui.font_atlas)

    ui.dcl = draw_new_draw_list()
    
    ui_init_input()
}

UI_Widget_Loop_Fn :: proc(^UI_Widget, rawptr)

ui_widget_ascending_loop :: proc(widget: ^UI_Widget, data: rawptr, fn: UI_Widget_Loop_Fn) -> u32 {
    count : u32 = 0

    if widget == nil {
        return count
    }

    if widget.first != nil {
        sentinel := widget.first
        for sentinel != nil {
            next := sentinel.next
            count += ui_widget_ascending_loop(sentinel, data, fn)
            sentinel = next
        }
    }

    count += 1
    fn(widget, data)

    return count
}

ui_widget_descending_loop :: proc(widget: ^UI_Widget, data: rawptr, fn: UI_Widget_Loop_Fn) -> u32 {
    count : u32 = 0

    if widget == nil {
        return count
    }

    count += 1
    fn(widget, data)

    if widget.first != nil {
        sentinel := widget.first
        for sentinel.next != nil {
            count += ui_widget_descending_loop(sentinel, data, fn)
            sentinel = sentinel.next
        }
    }

    count += ui_widget_descending_loop(widget.last, data, fn)

    return count
}

ui_begin :: proc() {
    mem.free_all(ui.temp_allocator)

    ui_update_input_events()
    ui.window_size = ui.app.window_size
    clear(&ui.parent_stack)
    ui_push_parent(ui.root)
}

UI_Layout :: struct {
    pos: Vec2,
}

ui_end :: proc() {
    ui_pop_parent()
    assert(len(ui.parent_stack) == 0)
    assert(len(ui.flag_add_stack) == 0)
    assert(len(ui.flag_rem_stack) == 0)

    // DO LAYOUT HERE

    ui_layout_root(ui.root)

    // Layout - Step 1
    layout: UI_Layout
    ui_widget_descending_loop(ui.root, cast(rawptr)&layout, proc(w: ^UI_Widget, data: rawptr) {
        if w.parent == nil do return
        layout := cast(^UI_Layout)data

        text_content_dim := ui_size_is_kind(w, UI_Size_Kind.TextContent) ? calc_text_size(ui.font, w.str, ui.font_size) : Vec2{0, 0}
        
        if ui_size_is_kind(w, UI_Axis.X, UI_Size_Kind.Pixels) {
            w.size.x = w.semantic_sizes[.X].value
        } else if ui_size_is_kind(w, UI_Axis.X, UI_Size_Kind.TextContent) {
            w.size.x = text_content_dim.x
        }
        
        if ui_size_is_kind(w, UI_Axis.Y, UI_Size_Kind.Pixels) {
            w.size.y = w.semantic_sizes[.Y].value
        } else if ui_size_is_kind(w, UI_Axis.Y, UI_Size_Kind.TextContent) {
            w.size.y = text_content_dim.y
        }
    })
    
    // Layout - Step 2
    ui_widget_descending_loop(ui.root, cast(rawptr)&layout, proc(w: ^UI_Widget, data: rawptr) {
        if w.parent == nil do return
        layout := cast(^UI_Layout)data
 
        if ui_size_is_kind(w, UI_Axis.X, UI_Size_Kind.PercentOfParent) {
            w.size.x = w.parent.size.x * w.semantic_sizes[.X].value
        }

        if ui_size_is_kind(w, UI_Axis.Y, UI_Size_Kind.PercentOfParent) {
            w.size.y = w.parent.size.y * w.semantic_sizes[.Y].value
        }
    })

    // Can optimize this
    ui_widget_descending_loop(ui.root, cast(rawptr)&layout, proc(w: ^UI_Widget, data: rawptr) {
        if w.parent == nil do return
        layout := cast(^UI_Layout)data
        
        is_leftover_x_or_y := ui_size_is_kind(w, UI_Size_Kind.LeftoverChildSum)
        if !is_leftover_x_or_y {
            return
        }

        num_leftovers_x, num_leftovers_y: i32
        total_size_x, total_size_y: f32
        sentinel := w.parent.first
        for sentinel != nil {
            if !ui_size_is_kind(sentinel, UI_Size_Kind.LeftoverChildSum) {
                total_size_x += sentinel.size.x
                total_size_y += sentinel.size.y
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
            w.size.x = (w.parent.size.x - total_size_x)*(w.semantic_sizes[.X].value != 0.0 ? w.semantic_sizes[.X].value : (1.0/f32(num_leftovers_x)))
        }

        if ui_size_is_kind(w, UI_Axis.Y, UI_Size_Kind.LeftoverChildSum) {
            w.size.y = (w.parent.size.y - total_size_y)*(w.semantic_sizes[.Y].value != 0.0 ? w.semantic_sizes[.Y].value : (1.0/f32(num_leftovers_y)))
        }
    })

    // FillX, FillY Loop
    ui_widget_descending_loop(ui.root, cast(rawptr)&layout, proc(w: ^UI_Widget, data: rawptr) {
        layout := cast(^UI_Layout)data

        if w.first != nil {
            parent_pad := ui_widget_calc_pad(w)

            total_size_x, total_size_y: f32 = 0, 0
            sentinel := w.first
            for sentinel != nil {
                if .FillY not_in sentinel.flags {
                    total_size_x += sentinel.size.x + parent_pad.x
                } else {
                    total_size_x = max(total_size_x, sentinel.size.x + parent_pad.x)
                }

                if .FillX not_in sentinel.flags {
                    total_size_y += sentinel.size.y + parent_pad.y
                } else {
                    total_size_y = max(total_size_y, sentinel.size.y + parent_pad.y)
                }

                sentinel = sentinel.next
            }

            if total_size_y > w.size.y {
                // Fix x sizes
                // Priority is removing size from spacers

                required_size_reduction := total_size_y - w.size.y + parent_pad.y

                total_percent_of_parent_count: i32 = 0
                total_percent_of_parent_size_y: f32 = 0.0
                total_spacer_count: i32 = 0
                total_spacer_size_y: f32 = 0.0
                sentinel = w.first
                for sentinel != nil {
                    if ui_size_is_kind(sentinel, UI_Axis.Y, UI_Size_Kind.LeftoverChildSum) && ui_match_null(sentinel) {
                        total_spacer_size_y += sentinel.size.y
                        total_spacer_count += 1
                    }
                    if ui_size_is_kind(sentinel, UI_Axis.Y, UI_Size_Kind.PercentOfParent) {
                        total_percent_of_parent_size_y += sentinel.size.y
                        total_percent_of_parent_count += 1
                    }
                    sentinel = sentinel.next
                }

                if total_spacer_count > 0 {
                    if total_spacer_size_y >= required_size_reduction {
                        
                        sentinel = w.first
                        for sentinel != nil {
                            if ui_size_is_kind(sentinel, UI_Axis.Y, UI_Size_Kind.LeftoverChildSum) && ui_match_null(sentinel) {
                                sentinel.size.y -= required_size_reduction/f32(total_spacer_count)
                            }
                            sentinel = sentinel.next
                        }
                    }
                } else {
                    if total_percent_of_parent_count > 0 {
                        sentinel = w.first
                        for sentinel != nil {
                            if ui_size_is_kind(sentinel, UI_Axis.Y, UI_Size_Kind.PercentOfParent) {
                                sentinel.size.y -= required_size_reduction/f32(total_percent_of_parent_count)
                            }
                            sentinel = sentinel.next
                        }
                    }
                }
            }

            if total_size_x > w.size.x {
                // Fix x sizes
                // Priority is removing size from spacers
    
                required_size_reduction := total_size_x - w.size.x + parent_pad.x
    
                total_percent_of_parent_count: i32 = 0
                total_percent_of_parent_size_x: f32 = 0.0
                total_spacer_count: i32 = 0
                total_spacer_size_x: f32 = 0.0
                sentinel = w.first
                for sentinel != nil {
                    if ui_size_is_kind(sentinel, UI_Axis.X, UI_Size_Kind.LeftoverChildSum) && ui_match_null(sentinel) {
                        total_spacer_size_x += sentinel.size.x
                        total_spacer_count += 1
                    }
                    if ui_size_is_kind(sentinel, UI_Axis.X, UI_Size_Kind.PercentOfParent) {
                        total_percent_of_parent_size_x += sentinel.size.x
                        total_percent_of_parent_count += 1
                    }
                    sentinel = sentinel.next
                }
    
                if total_spacer_count > 0 {
                    if total_spacer_size_x >= required_size_reduction {
                        
                        sentinel = w.first
                        for sentinel != nil {
                            if ui_size_is_kind(sentinel, UI_Axis.X, UI_Size_Kind.LeftoverChildSum) && ui_match_null(sentinel) {
                                sentinel.size.x -= required_size_reduction/f32(total_spacer_count)
                            }
                            sentinel = sentinel.next
                        }
                    }
                } else {
                    if total_percent_of_parent_count > 0 {
                        sentinel = w.first
                        for sentinel != nil {
                            if ui_size_is_kind(sentinel, UI_Axis.X, UI_Size_Kind.PercentOfParent) {
                                sentinel.size.x -= required_size_reduction/f32(total_percent_of_parent_count)
                            }
                            sentinel = sentinel.next
                        }
                    }
                }
            }
        }
    })

    ui_widget_descending_loop(ui.root, cast(rawptr)&layout, proc(w: ^UI_Widget, data: rawptr) {
        if w.parent == nil do return
        layout := cast(^UI_Layout)data

        parent := w.parent

        pad := ui_widget_calc_pad(parent)

        w.pos.x = parent.available_rect.x + 0.5*pad.x + w.offset.x
        w.pos.y = parent.available_rect.y + 0.5*pad.y + w.offset.y

        if .FillY in w.flags do parent.available_rect.y += w.size.y + pad.y
        if .FillX in w.flags do parent.available_rect.x += w.size.x + pad.x

        w.rect = rect_from_pos_dim(w.pos, w.size)
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

    ui_widget_descending_loop(ui.root, nil, proc(w: ^UI_Widget, data: rawptr) {
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
                draw_add_rect(ui.dcl, rect_grow(w.rect, pad_anim_pad), roundness, border_size, colors[0], border_color) 
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
    })
    
    ui.hot = ui.null
    ui.active = ui.null
    
    ui.widget_count = ui_widget_ascending_loop(ui.root, nil, proc(w: ^UI_Widget, data: rawptr) {
        w.i = ui_widget_interaction(w)
        
        if ui.hot == ui.null && (w.hot_condition != nil ? w->hot_condition() : w.i.hovered)  {
            ui_set_as_hot(w)
        }

        if ui.active == ui.null && ui_match_hot(w) && (w.active_condition != nil ? w->active_condition() : false) {
            ui_set_as_active(w)
        }

        w.parent = nil
        w.first = nil
        w.last = nil
        w.next = nil
        w.prev = nil
        
        w.hot_t -= 2.0*ui.app.dt
        w.active_t -= 2.0*ui.app.dt
        if w.hot_t <= 0.0 do w.hot_t = 0.0
        if w.active_t <= 0.0 do w.active_t = 0.0
    })
}

ui_free :: proc() {
    font_atlas_free(&ui.font_atlas)

    delete(ui.events)
    delete(ui.text)

    delete(ui.hash)
}
