package main

import "core:fmt"
import "core:log"
import "core:thread"
import "core:runtime"
import "core:strings"
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

	frame_time_text := format_string("Frame Time: %.2f ms", app.dt*1000.0)
	frame_time_pos := Vec2{20, 20}
	frame_time_rect := text_rect(frame_time_text, editor.size, frame_time_pos, Text_Render_Options{.Center})
	render(frame_time_rect, Color{0.0, 0.0, 0.0, 0.0}, 10.0, 2.0, 3.0, Color{0, 0, 0, 1})
	render(frame_time_text, editor.size, frame_time_pos, Text_Render_Options{.Center}, Color{1.0, 1.0, 1.0, 1.0})
}
