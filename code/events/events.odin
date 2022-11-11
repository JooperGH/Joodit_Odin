package platform

import la "core:math/linalg/glsl"

Event_Category :: enum {
    App,
    Window,
    Input,
    Keyboard,
    Mouse,
}

Base_Event :: struct {
    category: bit_set[Event_Category],
    handled: b32,
}

App_Update_Event :: struct {
    using base_event: Base_Event, 
}
app_update :: proc() -> Event {
    event := App_Update_Event{}
    event.category = {.App}
    event.handled = false
    return event
}

App_Render_Event :: struct {
    using base_event: Base_Event, 
}
app_render :: proc() -> Event {
    event := App_Render_Event{}
    event.category = {.App}
    event.handled = false
    return event
}

Window_Close_Event :: struct {
    using base_event: Base_Event,
}
window_close :: proc() -> Event {
    event := Window_Close_Event{}
    event.category = {.Window, .Input}
    event.handled = false
    return event
}

Window_Resized_Event :: struct {
    using base_event: Base_Event,
    size: la.vec2, 
}
window_resize :: proc(size: la.vec2) -> Event {
    event := Window_Resized_Event{}
    event.category = {.Window, .Input}
    event.handled = false
    event.size = size
    return event
}

Window_Moved_Event :: struct {
    using base_event: Base_Event,
    pos: la.vec2, 
}
window_moved :: proc(size: la.vec2) -> Event {
    event := Window_Moved_Event{}
    event.category = {.Window, .Input}
    event.handled = false
    event.pos = size
    return event
}

Window_Focus_Event :: struct {
    using base_event: Base_Event, 
    state: b32,
}
window_focus :: proc(state: b32) -> Event {
    event := Window_Focus_Event{}
    event.category = {.Window, .Input}
    event.handled = false
    event.state = state
    return event
}

Key_Pressed_Event :: struct {
    using base_event: Base_Event,
    key_code: i32,
    repeat_count: i32,
}
key_pressed :: proc(key_code: i32, repeat_count: i32) -> Event {
    event := Key_Pressed_Event{}
    event.category = {.Keyboard, .Input}
    event.handled = false
    event.key_code = key_code
    event.repeat_count = repeat_count
    return event
}

Key_Released_Event :: struct {
    using base_event: Base_Event,
    key_code: i32,
    repeat_count: i32,
}
key_released :: proc(key_code: i32, repeat_count: i32) -> Event {
    event := Key_Released_Event{}
    event.category = {.Keyboard, .Input}
    event.handled = false
    event.key_code = key_code
    event.repeat_count = repeat_count
    return event
}

Mouse_Pressed_Event :: struct {
    using base_event: Base_Event,
    button: i32,
}
mouse_pressed :: proc(button: i32) -> Event {
    event := Mouse_Pressed_Event{}
    event.category = {.Mouse, .Input}
    event.handled = false
    event.button = button
    return event
}

Mouse_Released_Event :: struct {
    using base_event: Base_Event,
    button: i32,
}
mouse_released :: proc(button: i32) -> Event {
    event := Mouse_Released_Event{}
    event.category = {.Mouse, .Input}
    event.handled = false
    event.button = button
    return event
}

Mouse_Moved_Event :: struct {
    using base_event: Base_Event,
    pos: la.vec2,
}
mouse_moved :: proc(pos: la.vec2) -> Event {
    event := Mouse_Moved_Event{}
    event.category = {.Mouse, .Input}
    event.handled = false
    event.pos = pos
    return event
}

Mouse_Scrolled_Event :: struct {
    using base_event: Base_Event,
    scroll: la.vec2,
}
mouse_scrolled :: proc(scroll: la.vec2) -> Event {
    event := Mouse_Scrolled_Event{}
    event.category = {.Mouse, .Input}
    event.handled = false
    event.scroll = scroll
    return event
}

Event :: union {
    Base_Event,
    App_Update_Event,
    App_Render_Event,
    Window_Close_Event,
    Window_Focus_Event,
    Window_Moved_Event,
    Window_Resized_Event,
    Key_Pressed_Event,
    Key_Released_Event,
    Mouse_Pressed_Event,
    Mouse_Released_Event,
    Mouse_Moved_Event,
    Mouse_Scrolled_Event,
}

name :: proc(e: Event) -> string {
    switch in e {
        case Base_Event:
            return "ERROR"
        case App_Update_Event:
            return "App Update"
        case App_Render_Event:
            return "App Render"
        case Window_Close_Event:
            return "Window Close"
        case Window_Focus_Event:
            return "Window Focus"
        case Window_Moved_Event:
            return "Window Moved"
        case Window_Resized_Event:
            return "Window Resized"
        case Key_Pressed_Event:
            return "Key Pressed"
        case Key_Released_Event:
            return "Key Released"
        case Mouse_Pressed_Event:
            return "Mouse Pressed"
        case Mouse_Released_Event:
            return "Mouse Released"
        case Mouse_Moved_Event:
            return "Mouse Moved"
        case Mouse_Scrolled_Event:
            return "Mouse Scrolled"
    }
    return "Unknown"
}