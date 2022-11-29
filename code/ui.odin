package main

UI_Widget_Comm :: struct {
    clicked: b32,
    hovered: b32,
}

UI_State :: struct {
    app: ^App,

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
}

ui := UI_State{}

ui_init :: proc(app: ^App) {
    ui.app = app

    ui_init_input()
}

ui_free :: proc() {
    delete(ui.events)
}


ui_button :: proc(text: string) -> UI_Widget_Comm {
    result: UI_Widget_Comm

    return result
}