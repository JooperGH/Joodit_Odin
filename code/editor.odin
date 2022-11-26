package main

import "core:fmt"
import "core:log"
import "core:thread"
import "core:runtime"
import "vendor:glfw"
import gl "vendor:OpenGL"
import "core:math/linalg/glsl"

Editor_Layer :: struct {
	using layer: Layer,

	tex: ^Texture,

	size: f32, 
}

editor_layer_on_attach :: proc(data: rawptr, app: ^App) {
	editor := cast(^Editor_Layer)data

	texture_load(&editor.tex, app, "textures/wood.png")

	editor.size = 30.0
}

editor_layer_on_detach :: proc(data: rawptr, app: ^App) {
	editor := cast(^Editor_Layer)data
	free(editor)
}

editor_on_mouse_moved :: proc(data: rawptr, app: ^App, e: ^Event) -> b32 {
	editor := cast(^Editor_Layer)data
	return false
}

editor_on_key_pressed :: proc(data: rawptr, app: ^App, e: ^Event) -> b32 {
	editor := cast(^Editor_Layer)data
	kp := e.type.(Key_Pressed_Event)

	if kp.key_code == glfw.KEY_E {
		editor.size += 60.0 * app.dt
	}

	if kp.key_code == glfw.KEY_Q {
		editor.size -= 60.0 * app.dt
	}

	if editor.size <= 1.0 {
		editor.size = 1.0
	}

	return false
}

editor_layer_on_event :: proc(data: rawptr, app: ^App, e: ^Event) {
	editor := cast(^Editor_Layer)data
	event_dispatch(data, e, app, Mouse_Moved_Event, editor_on_mouse_moved)
	event_dispatch(data, e, app, Key_Pressed_Event, editor_on_key_pressed)
}

editor_layer_on_update :: proc(data: rawptr, app: ^App) {
	editor := cast(^Editor_Layer)data
}

editor_layer_on_render :: proc(data: rawptr, app: ^App) {
	editor := cast(^Editor_Layer)data

	
	renderer_draw(string("Hello good world, SDF text rendering is working now! At last :>"), [2]f32{50, 400}, Rect{1.0, 1.0, 1.0, 1.0}, editor.size)
	renderer_draw_rect({50, 400, 55, 405}, {1, 0, 0, 1})
	renderer_draw_texture(editor.tex, {100, 200, 200, 300}, {1, 1, 1, 1})
}
