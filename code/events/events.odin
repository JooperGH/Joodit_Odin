package events

import la "core:math/linalg/glsl"

Event_Type :: enum {
    App_Update,
    App_Render,
    Window_Close,
    Window_Resize,
    Window_Moved,
    Window_Focus,
    Key_Pressed,
    Key_Released,
    Mouse_Pressed,
    Mouse_Released,
    Mouse_Moved,
    Mouse_Scrolled,
}

Event_Category :: enum {
    App,
    Window,
    Input,
    Keyboard,
    Mouse,
}

App_Update_Start_Event :: struct {
    time: f32,
}
app_update_start :: proc(time: f32) -> Event {
    event := Event{}
    event.handled = false
    event.category = {.App}
    event.type = App_Update_Start_Event{time}
    return event
}

App_Update_End_Event :: struct {
    time: f32,
}
app_update_end :: proc(time: f32) -> Event {
    event := Event{}
    event.handled = false
    event.category = {.App}
    event.type = App_Update_End_Event{time}
    return event
}

App_Render_Start_Event :: struct {
    time: f32,
}
app_render_start :: proc(time: f32) -> Event {
    event := Event{}
    event.handled = false
    event.category = {.App}
    event.type = App_Render_Start_Event{time}
    return event
}

App_Render_End_Event :: struct {
    time: f32,
}
app_render_end :: proc(time: f32) -> Event {
    event := Event{}
    event.handled = false
    event.category = {.App}
    event.type = App_Render_End_Event{time}
    return event
}

Window_Close_Event :: struct {
    exit_code: i32,
}
window_close :: proc(exit_code: i32) -> Event {
    event := Event{}
    event.handled = false
    event.category = {.Window, .Input}
    event.type = Window_Close_Event{exit_code}
    return event
}

Window_Resized_Event :: struct {
    size: la.vec2, 
}
window_resize :: proc(size: la.vec2) -> Event {
    event := Event{}
    event.handled = false
    event.category = {.Window, .Input}
    event.type = Window_Resized_Event{size}
    return event
}

Window_Moved_Event :: struct {
    pos: la.vec2, 
}
window_moved :: proc(pos: la.vec2) -> Event {
    event := Event{}
    event.handled = false
    event.category = {.Window, .Input}
    event.type = Window_Moved_Event{pos}
    return event
}

Window_Focus_Event :: struct {
    state: b32,
}
window_focus :: proc(state: b32) -> Event {
    event := Event{}
    event.handled = false
    event.category = {.Window, .Input}
    event.type = Window_Focus_Event{state}
    return event
}

Key_Pressed_Event :: struct {
    key_code: i32,
    repeat_count: i32,
}
key_pressed :: proc(key_code: i32, repeat_count: i32) -> Event {
    event := Event{}
    event.handled = false
    event.category = {.Keyboard, .Input}
    event.type = Key_Pressed_Event{key_code, repeat_count}
    return event
}

Key_Released_Event :: struct {
    key_code: i32,
    repeat_count: i32,
}
key_released :: proc(key_code: i32, repeat_count: i32) -> Event {
    event := Event{}
    event.handled = false
    event.category = {.Keyboard, .Input}
    event.type = Key_Released_Event{key_code, repeat_count}
    return event
}

Mouse_Pressed_Event :: struct {
    button: i32,
}
mouse_pressed :: proc(button: i32) -> Event {
    event := Event{}
    event.handled = false
    event.category = {.Mouse, .Input}
    event.type = Mouse_Pressed_Event{button}
    return event
}

Mouse_Released_Event :: struct {
    button: i32,
}
mouse_released :: proc(button: i32) -> Event {
    event := Event{}
    event.handled = false
    event.category = {.Mouse, .Input}
    event.type = Mouse_Released_Event{button}
    return event
}

Mouse_Moved_Event :: struct {
    pos: la.vec2,
}
mouse_moved :: proc(pos: la.vec2) -> Event {
    event := Event{}
    event.handled = false
    event.category = {.Mouse, .Input}
    event.type = Mouse_Moved_Event{pos}
    return event
}

Mouse_Scrolled_Event :: struct {
    scroll: la.vec2,
}
mouse_scrolled :: proc(scroll: la.vec2) -> Event {
    event := Event{}
    event.handled = false
    event.category = {.Mouse, .Input}
    event.type = Mouse_Scrolled_Event{scroll}
    return event
}

Event :: struct {
    handled: b32,
    category: bit_set[Event_Category],

    type: union{
        App_Update_Start_Event, 
        App_Update_End_Event,
        App_Render_Start_Event,
        App_Render_End_Event,
        Window_Close_Event,
        Window_Resized_Event,
        Window_Moved_Event,
        Window_Focus_Event,
        Key_Pressed_Event,
        Key_Released_Event,
        Mouse_Pressed_Event,
        Mouse_Released_Event,
        Mouse_Moved_Event,
        Mouse_Scrolled_Event,
    },
}
