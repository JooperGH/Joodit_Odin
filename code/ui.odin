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
    flag_stack: [dynamic]UI_Widget_Flags,
    
    null: UI_ID,
    hot: UI_ID,
    active: UI_ID,
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
    ui.flag_stack = make([dynamic]UI_Widget_Flags, 0, 10)

    ui.null, _ = ui_get_id("")
    ui.hot = ui.null
    ui.active = ui.null

    ui.font_size = 32.0
    font_load(&ui.font, app, "fonts/OpenSans-Regular.ttf", 30, Font_Glyph_Range_Default, Font_Raster_Type.SDF, 2048, 2048, false)
    
    ui_init_input()
}

UI_Widget_Loop_Fn :: proc(^UI_Widget)

ui_widget_ascending_loop :: proc(widget: ^UI_Widget, fn: UI_Widget_Loop_Fn) -> u32 {
    count : u32 = 0

    if widget == nil {
        return count
    }

    if widget.first != nil {
        sentinel := widget.first
        for sentinel != nil {
            next := sentinel.next
            count += ui_widget_ascending_loop(sentinel, fn)
            sentinel = next
        }
    }

    count += 1
    fn(widget)

    return count
}

ui_widget_descending_loop :: proc(widget: ^UI_Widget, fn: UI_Widget_Loop_Fn) -> u32 {
    count : u32 = 0

    if widget == nil {
        return count
    }

    count += 1
    fn(widget)

    if widget.first != nil {
        sentinel := widget.first
        for sentinel.next != nil {
            count += ui_widget_descending_loop(sentinel, fn)
            sentinel = sentinel.next
        }
    }

    count += ui_widget_descending_loop(widget.last, fn)

    return count
}

ui_begin :: proc() {
    mem.free_all(ui.temp_allocator)

    ui_update_input_events()
    ui.window_size = ui.app.window_size
    clear(&ui.parent_stack)
    ui_push_parent(ui.root)
}

ui_end :: proc() {
    ui_pop_parent()
    assert(len(ui.parent_stack) == 0)
    assert(len(ui.flag_stack) == 0)

    // DO LAYOUT HERE
    
    ui_widget_descending_loop(ui.root, proc(w: ^UI_Widget) {
        if w.parent == nil {
            ui_layout_root(w)
            return
        } 

        w.size = ui_layout_calc_size(w)
        ui_layout_calc_pos(w)
        w.rect = rect_from_pos_dim(w.pos, w.size) 
        w.available_rect = w.rect
    })

    ui_widget_descending_loop(ui.root, proc(w: ^UI_Widget) {
        if .Ignore in w.flags {
            return
        }

        pad_anim_factor : f32 = 4.0*ui_widget_anim(w, 0.25, 8.0)
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
                render(rect_grow(w.rect, pad_anim_pad), colors, roundness, softness, border_size, border_color)
            } else {
                color := bg_anim * w.style.colors[.Bg]
                render(rect_grow(w.rect, pad_anim_pad), color, roundness, softness, border_size, border_color)    
            }

		}

		if .DrawText in w.flags {
            anim := .TextAnimation in w.flags ? ui_widget_anim(w, 0.5) : 0.0
            color := anim*Color{1.0, 1.0, 0.0, 1.0}+(1.0-anim)*Color{1, 1, 1, 1}
			render(ui.font, w.str, ui.font_size, rect_center(w.rect), Text_Render_Options{.Center}, color)
		}
    })
    
    ui.widget_count = ui_widget_ascending_loop(ui.root, proc(w: ^UI_Widget) {
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

    ui.hot = ui.null
    ui.active = ui.null
}

ui_free :: proc() {
    font_free(&ui.font)

    delete(ui.events)
    delete(ui.text)

    delete(ui.hash)
}
