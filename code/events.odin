package main

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
events_app_update_start :: proc(time: f32) -> ^Event {
    event := new(Event, context.temp_allocator)
    event.handled = false
    event.category = {.App}
    event.type = App_Update_Start_Event{time}
    return event
}

App_Update_End_Event :: struct {
    time: f32,
}
events_app_update_end :: proc(time: f32) -> ^Event {
    event := new(Event, context.temp_allocator)
    event.handled = false
    event.category = {.App}
    event.type = App_Update_End_Event{time}
    return event
}

App_Render_Start_Event :: struct {
    time: f32,
}
events_app_render_start :: proc(time: f32) -> ^Event {
    event := new(Event, context.temp_allocator)
    event.handled = false
    event.category = {.App}
    event.type = App_Render_Start_Event{time}
    return event
}

App_Render_End_Event :: struct {
    time: f32,
}
events_app_render_end :: proc(time: f32) -> ^Event {
    event := new(Event, context.temp_allocator)
    event.handled = false
    event.category = {.App}
    event.type = App_Render_End_Event{time}
    return event
}

Window_Close_Event :: struct {
    exit_code: i32,
}
events_window_close :: proc(exit_code: i32) -> ^Event {
    event := new(Event, context.temp_allocator)
    event.handled = false
    event.category = {.Window, .Input}
    event.type = Window_Close_Event{exit_code}
    return event
}

Window_Resized_Event :: struct {
    size: Vec2, 
}
events_window_resize :: proc(size: Vec2) -> ^Event {
    event := new(Event, context.temp_allocator)
    event.handled = false
    event.category = {.Window, .Input}
    event.type = Window_Resized_Event{size}
    return event
}

Window_Moved_Event :: struct {
    pos: Vec2, 
}
events_window_moved :: proc(pos: Vec2) -> ^Event {
    event := new(Event, context.temp_allocator)
    event.handled = false
    event.category = {.Window, .Input}
    event.type = Window_Moved_Event{pos}
    return event
}

Window_Focus_Event :: struct {
    state: b32,
}
events_window_focus :: proc(state: b32) -> ^Event {
    event := new(Event, context.temp_allocator)
    event.handled = false
    event.category = {.Window, .Input}
    event.type = Window_Focus_Event{state}
    return event
}

Key_Event :: struct {
    key_code: Key_Code,
    down: b32,
}
events_key :: proc(key_code: i32, down: b32) -> ^Event {
    event := new(Event, context.temp_allocator)
    event.handled = false
    event.category = {.Keyboard, .Input}
    event.type = Key_Event{key_code_from_glfw(key_code), down}
    return event
}


Button_Event :: struct {
    button: Button_Code,
    down: b32,
}
events_button :: proc(button: i32, down: b32) -> ^Event {
    event := new(Event, context.temp_allocator)
    event.handled = false
    event.category = {.Mouse, .Input}
    event.type = Button_Event{button_code_from_glfw(button), down}
    return event
}

Mod_Event :: struct {
    mod_code: Mod_Code,
    down: b32,
}
events_mod_glfw :: proc(mod_code: i32, down: b32) -> ^Event {
    event := new(Event, context.temp_allocator)
    event.handled = false
    event.category = {.Keyboard, .Input}
    event.type = Mod_Event{mod_code_from_glfw(mod_code), down}
    return event
}
events_mod :: proc(mod_code: Mod_Code, down: b32) -> ^Event {
    event := new(Event, context.temp_allocator)
    event.handled = false
    event.category = {.Keyboard, .Input}
    event.type = Mod_Event{mod_code, down}
    return event
}

Mouse_Moved_Event :: struct {
    pos: Vec2,
}
events_mouse_moved :: proc(pos: Vec2) -> ^Event {
    event := new(Event, context.temp_allocator)
    event.handled = false
    event.category = {.Mouse, .Input}
    event.type = Mouse_Moved_Event{pos}
    return event
}

Mouse_Scrolled_Event :: struct {
    scroll: Vec2,
}
events_mouse_scrolled :: proc(scroll: Vec2) -> ^Event {
    event := new(Event, context.temp_allocator)
    event.handled = false
    event.category = {.Mouse, .Input}
    event.type = Mouse_Scrolled_Event{scroll}
    return event
}

Input_Character_Event :: struct {
    c: rune,
}
events_input_character :: proc(c: rune) -> ^Event {
    event := new(Event, context.temp_allocator)
    event.handled = false
    event.category = {.Mouse, .Input}
    event.type = Input_Character_Event{c}
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
        Key_Event,
        Button_Event,
        Mod_Event,
        Mouse_Moved_Event,
        Mouse_Scrolled_Event,
        Input_Character_Event,
    },
}
