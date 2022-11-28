package main

UI_Widget_Comm :: struct {
    clicked: b32,
    hovered: b32,
}

UI_State :: struct {
    app: ^App,

    events: [dynamic]^Event,

    keys:    [Key_Code.Last]b32,
    buttons: [Button_Code.Last]b32,
    mods:    [Mod_Code.Last]b32,
    mouse_pos: Vec2,
    scroll_pos: Vec2,
    focused: b32,
}

ui := UI_State{}

ui_init :: proc(app: ^App) {
    ui.app = app
}

ui_free :: proc() {

}


ui_button :: proc(text: string) -> UI_Widget_Comm {
    result: UI_Widget_Comm

    return result
}