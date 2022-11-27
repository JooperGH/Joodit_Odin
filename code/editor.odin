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

	mouse_pos := input_mouse_pos(app)
	/*
	render(Rect{mouse_pos.x, mouse_pos.y, mouse_pos.x+200, mouse_pos.y+200}, Color{1, 1, 1, 1}, 20.0, 2.0, 5.0, Color{0, 0, 0, 1})
	render(editor.tex, Rect{100, 100, 300, 300}, Color{1, 1, 1, 1}, 20.0, 2.0, 5.0, Color{0, 0, 0, 1})
	render(string("Hello good world, SDF text rendering is working now! At last :>"), editor.size, Vec2{50, 400}, Text_Render_Options{.Center}, Color{1.0, 1.0, 1.0, 1.0})

	b := strings.builder_make(context.temp_allocator)
	
	*/

	frame_time_text := format_string("Frame Time: %.2f ms", app.dt*1000.0)
	
 	line_gap := text_line_advance(editor.size)

	frame_time_pos := Vec2{300, 300}
	frame_time_rect := text_rect(frame_time_text, editor.size, frame_time_pos)
	render(rect_from_center_dim(rect_center(frame_time_rect), Vec2{10,10}), Color{0.5, 0.5, 0.5, 1.0})
	render(frame_time_text, editor.size, frame_time_pos, Text_Render_Options{.Hor_Left, .Ver_Top}, Color{1.0, 1.0, 1.0, 1.0})

	frame_time_pos.y += line_gap*2.0
	frame_time_rect = text_rect(frame_time_text, editor.size, frame_time_pos)
	render(rect_from_center_dim(rect_center(frame_time_rect), Vec2{10,10}), Color{0.5, 0.5, 0.5, 1.0})
	render(frame_time_text, editor.size, frame_time_pos, Text_Render_Options{.Hor_Left, .Center}, Color{1.0, 1.0, 1.0, 1.0})

	frame_time_pos.y += line_gap*2.0
	frame_time_rect = text_rect(frame_time_text, editor.size, frame_time_pos)
	render(rect_from_center_dim(rect_center(frame_time_rect), Vec2{10,10}), Color{0.5, 0.5, 0.5, 1.0})
	render(frame_time_text, editor.size, frame_time_pos, Text_Render_Options{.Hor_Left, .Ver_Bottom}, Color{1.0, 1.0, 1.0, 1.0})
	
	frame_time_pos = Vec2{600, 300}
	frame_time_rect = text_rect(frame_time_text, editor.size, frame_time_pos)
	render(rect_from_center_dim(rect_center(frame_time_rect), Vec2{10,10}), Color{0.5, 0.5, 0.5, 1.0})
	render(frame_time_text, editor.size, frame_time_pos, Text_Render_Options{.Center, .Ver_Top}, Color{1.0, 1.0, 1.0, 1.0})

	frame_time_pos.y += line_gap*2.0
	frame_time_rect = text_rect(frame_time_text, editor.size, frame_time_pos)
	render(rect_from_center_dim(rect_center(frame_time_rect), Vec2{10,10}), Color{0.5, 0.5, 0.5, 1.0})
	render(frame_time_text, editor.size, frame_time_pos, Text_Render_Options{.Center, .Center}, Color{1.0, 1.0, 1.0, 1.0})

	frame_time_pos.y += line_gap*2.0
	frame_time_rect = text_rect(frame_time_text, editor.size, frame_time_pos)
	render(rect_from_center_dim(rect_center(frame_time_rect), Vec2{10,10}), Color{0.5, 0.5, 0.5, 1.0})
	render(frame_time_text, editor.size, frame_time_pos, Text_Render_Options{.Center, .Ver_Bottom}, Color{1.0, 1.0, 1.0, 1.0})
	
	frame_time_pos = Vec2{900, 300}
	frame_time_rect = text_rect(frame_time_text, editor.size, frame_time_pos)
	render(rect_from_center_dim(rect_center(frame_time_rect), Vec2{10,10}), Color{0.5, 0.5, 0.5, 1.0})
	render(frame_time_text, editor.size, frame_time_pos, Text_Render_Options{.Hor_Right, .Ver_Top}, Color{1.0, 1.0, 1.0, 1.0})

	frame_time_pos.y += line_gap*2.0
	frame_time_rect = text_rect(frame_time_text, editor.size, frame_time_pos)
	render(rect_from_center_dim(rect_center(frame_time_rect), Vec2{10,10}), Color{0.5, 0.5, 0.5, 1.0})
	render(frame_time_text, editor.size, frame_time_pos, Text_Render_Options{.Hor_Right, .Center}, Color{1.0, 1.0, 1.0, 1.0})

	frame_time_pos.y += line_gap*2.0
	frame_time_rect = text_rect(frame_time_text, editor.size, frame_time_pos)
	render(rect_from_center_dim(rect_center(frame_time_rect), Vec2{10,10}), Color{0.5, 0.5, 0.5, 1.0})
	render(frame_time_text, editor.size, frame_time_pos, Text_Render_Options{.Hor_Right, .Ver_Bottom}, Color{1.0, 1.0, 1.0, 1.0})
	
}
