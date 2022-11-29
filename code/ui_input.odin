package main

import "core:fmt"
import "core:math"

Key_Data :: struct {
    down: b32,
    duration: f32,
    prev_duration: f32,
}

ui_init_input :: proc() {
    for k in &ui.keys {
        k.down = false
        k.duration = -1.0
        k.prev_duration = -1.0
    }
    
    for k in &ui.buttons {
        k.down = false
        k.duration = -1.0
        k.prev_duration = -1.0
    }

    for k in &ui.mods {
        k.down = false
        k.duration = -1.0
        k.prev_duration = -1.0
    }

    ui.mouse_pos = {-math.F32_MAX, -math.F32_MAX}
    ui.mouse_dpos = {0.0, 0.0}
    ui.scroll_pos = {0.0, 0.0}
    ui.focused = true
}

ui_add_event :: proc(e: ^Event) {
    if ui.events == nil {
        ui.events = make([dynamic]^Event, 0, 128)
    }

    #partial switch v in e.type {
        case Key_Event:
            assert(v.key_code > Key_Code.First && v.key_code < Key_Code.Last)
            append(&ui.events, e)
        case Mod_Event:
            assert(v.mod_code > Mod_Code.First && v.mod_code < Mod_Code.Last)
            append(&ui.events, e)
        case Button_Event:          
            assert(v.button > Button_Code.First && v.button < Button_Code.Last)
            append(&ui.events, e)
        case Mouse_Moved_Event:
            append(&ui.events, e)
        case Mouse_Scrolled_Event:
            append(&ui.events, e)
    }
}

@(private)
ui_update_input_events :: proc() {
    mouse_moved, mouse_scrolled, key_changed, button_changed: b32
    
    for k in &ui.keys {
        k.prev_duration = k.duration
        k.duration = k.down ? (k.duration < 0.0 ?  0.0 : k.duration + ui.app.dt) : -1.0
    }
    
    for k in &ui.buttons {
        k.prev_duration = k.duration
        k.duration = k.down ? (k.duration < 0.0 ?  0.0 : k.duration + ui.app.dt) : -1.0
    }

    for k in &ui.mods {
        k.prev_duration = k.duration
        k.duration = k.down ? (k.duration < 0.0 ?  0.0 : k.duration + ui.app.dt) : -1.0
    }

    for e in ui.events {
        #partial switch v in e.type {
        case Button_Event:
            ui.buttons[v.button].down = v.down
            button_changed = true
        case Key_Event:
            ui.keys[v.key_code].down = v.down
            key_changed = true
        case Mod_Event:
            ui.mods[v.mod_code].down = v.down
        case Mouse_Moved_Event:
            ui.mouse_pos = v.pos
            mouse_moved = true
        case Mouse_Scrolled_Event:
            ui.scroll_pos += v.scroll
            mouse_scrolled = true
        }
    }

    clear(&ui.events)
}

ui_input_pressed :: proc{ui_key_pressed, ui_button_pressed}
ui_input_down :: proc{ui_key_down, ui_button_down}
ui_input_released :: proc{ui_key_released, ui_button_released}

ui_key_pressed :: proc(k: Key_Code) -> b32 {
    return ui.keys[k].down && (ui.keys[k].duration == 0.0) && (ui.keys[k].prev_duration < 0.0)
}

ui_key_down :: proc(k: Key_Code) -> b32 {
    return ui.keys[k].down && (ui.keys[k].duration >= 0.0)
}

ui_key_released :: proc(k: Key_Code) -> b32 {
    return !ui.keys[k].down && (ui.keys[k].duration < 0.0) && (ui.keys[k].prev_duration >= 0.0)
}

ui_button_pressed :: proc(k: Button_Code) -> b32 {
    return ui.buttons[k].down && (ui.buttons[k].duration == 0.0) && (ui.buttons[k].prev_duration < 0.0)
}

ui_button_down :: proc(k: Button_Code) -> b32 {
    return ui.buttons[k].down && (ui.buttons[k].duration >= 0.0)
}

ui_button_released :: proc(k: Button_Code) -> b32 {
    return !ui.buttons[k].down && (ui.buttons[k].duration < 0.0) && (ui.buttons[k].prev_duration >= 0.0)
}