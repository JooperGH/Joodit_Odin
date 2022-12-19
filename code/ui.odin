package main

import "core:mem"
import "core:fmt"
import "core:math"
import "core:log"


UI_State :: struct {
    app: ^App,
    allocator: mem.Allocator,
    temp_allocator: mem.Allocator,

    font_size: f32,
    font_atlas: ^Font_Atlas,
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

    dcl: ^Draw_Cmd_List,
}

ui := UI_State{}

ui_init :: proc(app: ^App) {
    ui.app = app
        
    arena := new(mem.Arena)
    mem.arena_init(arena, make([]byte, 2*mem.Megabyte))
    ui.temp_allocator = mem.arena_allocator(arena)
    
    arena = new(mem.Arena)
    mem.arena_init(arena, make([]byte, 1*mem.Megabyte))
    ui.allocator = mem.arena_allocator(arena)
    
    ui_init_input()
    ui.window_size = app.window_size

    ui.font_size = 32.0
    ui.font_atlas = font_atlas_create()
    ui.font = font_atlas_add_font_from_ttf(ui.font_atlas, app, "fonts/OpenSans-Regular.ttf", 30.0)
    ui.font.configs[0].oversample_x = 2
    ui.font.configs[0].oversample_y = 2
    font_atlas_build(ui.font_atlas)
    ui.dcl = draw_new_draw_list()
}

ui_begin :: proc() {
    mem.free_all(ui.temp_allocator)
    ui.window_size = ui.app.window_size
    ui_update_input_events()
}

ui_end :: proc() {

}

ui_free :: proc() {
    font_atlas_free(&ui.font_atlas)

    delete(ui.events)
    delete(ui.text)
}
