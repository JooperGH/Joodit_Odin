package main

import "core:fmt"

Key_Data :: struct {
    down: b32,
    duration: f32,
    prev_duration: f32,
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

ui_update_input_events :: proc() {
    mouse_moved, mouse_wheeled, key_changed, mouse_button_changed: b32

    for e in ui.events {
        #partial switch v in e.type {
        case Button_Event:
            ui.buttons[v.button] = true
        case Key_Event:
            ui.keys[v.key_code] = true
        case Mod_Event:
            ui.mods[v.mod_code] = v.down
        case Mouse_Moved_Event:
            ui.mouse_pos = v.pos
        case Mouse_Scrolled_Event:
            ui.scroll_pos = v.scroll
        }
    }

    clear(&ui.events)
}