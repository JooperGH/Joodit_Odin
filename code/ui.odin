package main

import "core:mem"
import "core:fmt"
import "core:math"

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

    ui.null, _ = ui_get_id("")
    ui.hot = ui.null
    ui.active = ui.null

    ui.font_size = 30.0
    font_load(&ui.font, app, "fonts/OpenSans-Regular.ttf", 40, Font_Glyph_Range_Default, Font_Raster_Type.SDF, 2048, 2048, false)
    
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

    count += ui_widget_ascending_loop(widget.last, fn)

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

    ui_widget_descending_loop(ui.root, proc(w: ^UI_Widget) {
        if .Ignore in w.flags {
            return
        }

        pad_anim := 2.0 + 6.0*ui_widget_anim(w, 0.25, 8.0)
        pad := Vec2{
            .HorPad in w.flags ? pad_anim: 0.0,
            .VerPad in w.flags ? pad_anim : 0.0,
        }

        if .DrawBackground in w.flags {
            anim := 1.0 + ui_widget_anim(w, 0.5, 12.0)
            border_thickness : f32 = .DrawBorder in w.flags ? 1.0 : 0.0
			render(rect_grow(w.rect, pad), [2]Color{anim*Color{0.15, 0.15, 0.15, 1.0}, anim*Color{0.125, 0.125, 0.125, 1.0}}, 4.0, 1.0, border_thickness, Color{0.8, 0.8, 0.8, 1.0})
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

        w.rect = {5.0, 5.0, ui.window_size.x-5.0, ui.window_size.y-5.0}
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

ui_button :: proc(text: string) -> UI_Widget_Interaction {
    widget := ui_widget_create({.Clickable,
                                .DrawBackground,
                                .DrawBorder,
                                .DrawText,
                                .HorPad,
                                .HotAnimation,
                                .ActiveAnimation},
                                text)

    i := ui_widget_interaction(widget)
    
    if i.hovered {
        ui_set_as_hot(widget)
    }

    if i.left_down && ui_match_hot(widget) {
        ui_set_as_active(widget)
    }

    return i
}

ui_text :: proc(text: string) -> UI_Widget_Interaction {
    widget := ui_widget_create({.DrawText,
                                .TextAnimation,
                                .HotAnimation,
                                .ActiveAnimation},
                                text)

    i := ui_widget_interaction(widget)
    
    if i.hovered {
        ui_set_as_hot(widget)
    }

    return i
}