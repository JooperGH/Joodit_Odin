package main

import "core:fmt"
import "core:math"

Key_Data :: struct {
    down: b32,
    double_click: b32,
    duration: f32,
    prev_duration: f32,
    last_press: f32,
    last_release: f32,
}

ui_init_input :: proc() {
    for k in &ui.keys {
        k.down = false
        k.double_click = false
        k.duration = -1.0
        k.prev_duration = -1.0
        k.last_press = -math.F32_MAX
        k.last_release = -math.F32_MAX
    }
    
    for k in &ui.buttons {
        k.down = false
        k.double_click = false
        k.duration = -1.0
        k.prev_duration = -1.0
        k.last_press = -math.F32_MAX
        k.last_release = -math.F32_MAX
    }

    for k in &ui.mods {
        k.down = false
        k.double_click = false
        k.duration = -1.0
        k.prev_duration = -1.0
        k.last_press = -math.F32_MAX
        k.last_release = -math.F32_MAX
    }

    ui.mouse_pos = {-math.F32_MAX, -math.F32_MAX}
    ui.mouse_dpos = {0.0, 0.0}
    ui.scroll_pos = {0.0, 0.0}
    ui.focused = true

    ui.events = make([dynamic]^Event, 0, 128)
    ui.text = make([dynamic]rune, 0, 128)
}

ui_add_event :: proc(e: ^Event) {
    append(&ui.events, e)
}

@(private)
ui_update_input_events :: proc() {
    mouse_moved, mouse_scrolled, key_changed, button_changed: b32

    time := app_time()
    
    for k in &ui.keys {
        k.prev_duration = k.duration
        k.duration = k.down ? (k.duration < 0.0 ?  0.0 : k.duration + ui.app.dt) : -1.0
        k.double_click = false
    }
    
    for k in &ui.buttons {
        k.prev_duration = k.duration
        k.duration = k.down ? (k.duration < 0.0 ?  0.0 : k.duration + ui.app.dt) : -1.0
        k.double_click = false
    }

    for k in &ui.mods {
        k.prev_duration = k.duration
        k.duration = k.down ? (k.duration < 0.0 ?  0.0 : k.duration + ui.app.dt) : -1.0
        k.double_click = false
    }

    ui.mouse_dpos = {0, 0}
    
    for e in ui.events {
        #partial switch v in e.type {
        case Button_Event:
            k := &ui.buttons[v.button]
            k.down = v.down

            if k.down {
                last_press := k.last_press
                k.last_press = time
    
                if k.last_press - last_press <= 0.2 {
                    k.double_click = true
                    k.last_press = -math.F32_MAX
                }
            } else {
                k.last_press = time
            }

            button_changed = true
        case Key_Event:
            k := &ui.keys[v.key_code]
            k.down = v.down

            if k.down {
                last_press := k.last_press
                k.last_press = time
    
                if k.last_press - last_press <= 0.2 {
                    k.double_click = true
                    k.last_press = -math.F32_MAX
                }
            } else {
                k.last_press = time
            }

            key_changed = true
        case Mod_Event:
            ui.mods[v.mod_code].down = v.down
        case Mouse_Moved_Event:
            pos_fixed := Vec2{v.pos.x, ui.window_size.y - v.pos.y}
            ui.last_valid_mouse_pos = v.pos
            ui.prev_mouse_pos = ui.mouse_pos
            ui.mouse_pos = pos_fixed
            mouse_moved = true
        case Mouse_Scrolled_Event:
            ui.scroll_pos += v.scroll
            mouse_scrolled = true
        case Input_Character_Event:
            append(&ui.text, v.c)
        case Window_Resized_Event:
            ui.window_size = v.size

            if ui.root != nil {
                ui.root.semantic_sizes[.X] = {
                    .PercentOfParent,
                    1.0,
                    0.0,
                }
                ui.root.semantic_sizes[.Y] = {
                    .PercentOfParent,
                    1.0,
                    0.0,
                }
            }
        }
        
    }

    if mouse_moved {
        ui.mouse_dpos = ui.mouse_pos - ui.prev_mouse_pos
    }

    ui.mods_set = {}
    if ui.mods[Mod_Code.Ctrl].down do ui.mods_set += {.Ctrl}
    if ui.mods[Mod_Code.Shift].down do ui.mods_set += {.Shift}
    if ui.mods[Mod_Code.Alt].down do ui.mods_set += {.Alt}
    if ui.mods[Mod_Code.Super].down do ui.mods_set += {.Super}

    clear(&ui.events)
}

ui_input_pressed :: proc{ui_key_pressed, ui_button_pressed}
ui_input_down :: proc{ui_key_down, ui_button_down}
ui_input_released :: proc{ui_key_released, ui_button_released}
ui_input_double_pressed :: proc{ui_key_double_pressed, ui_button_double_pressed}

ui_key_double_pressed :: proc(k: Key_Code) -> b32 {
    return (ui.keys[k].double_click)
}

ui_key_pressed :: proc(k: Key_Code) -> b32 {
    return ui.keys[k].down && (ui.keys[k].duration == 0.0) && (ui.keys[k].prev_duration < 0.0)
}

ui_key_down :: proc(k: Key_Code) -> b32 {
    return ui.keys[k].down && (ui.keys[k].duration >= 0.0)
}

ui_key_released :: proc(k: Key_Code) -> b32 {
    return !ui.keys[k].down && (ui.keys[k].duration < 0.0) && (ui.keys[k].prev_duration >= 0.0)
}

ui_button_double_pressed :: proc(k: Button_Code) -> b32 {
    return (ui.buttons[k].double_click)
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
