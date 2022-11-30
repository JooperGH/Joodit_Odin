package main

import "core:fmt"
import "core:log"
import "core:thread"
import "core:runtime"
import "core:strings"
import "core:math/linalg/glsl"
import "core:unicode/utf8"
import "vendor:glfw"

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

editor_layer_on_event :: proc(data: rawptr, app: ^App, e: ^Event) {
	editor := cast(^Editor_Layer)data
}

editor_layer_on_update :: proc(data: rawptr, app: ^App) {
	editor := cast(^Editor_Layer)data

	ui_text(format_string("Frame time: %.2f ms###Frame Timer 1", app.dt*1000.0)) 
}

editor_layer_on_render :: proc(data: rawptr, app: ^App) {
	editor := cast(^Editor_Layer)data

	/*
	frame_time_text := format_string("Frame Time: %.2f ms", app.dt*1000.0)
	frame_time_pos := Vec2{400, 400}
	frame_time_rect := text_rect(ui.font, frame_time_text, editor.size, frame_time_pos, Text_Render_Options{.Center})
	render(frame_time_rect, Color{0.0, 0.0, 0.0, 0.0}, 0.0, 0.0, 1.0, Color{1, 0, 0, 1})
	render(ui.font, frame_time_text, editor.size, frame_time_pos, Text_Render_Options{.Ver_Top, .Hor_Right}, Color{1.0, 1.0, 1.0, 1.0})
	
	sentinel := ui.root.first
	for sentinel != nil {
		if .DrawBackground in sentinel.flags {
			//render(sentinel.rect, Color{0.15, 0.15, 0.15, 1.0})
		}
		if .DrawBorder in sentinel.flags {
			//render(sentinel.rect, Color{0, 0, 0, 0}, 0, 0, 1.0, Color{0.8, 0.8, 0.8, 1.0})
		}
		if .DrawText in sentinel.flags {
			render(ui.font, frame_time_text, editor.size, frame_time_pos, Text_Render_Options{.Ver_Top, .Hor_Right}, Color{1.0, 1.0, 1.0, 1.0})
			//render(ui.font, sentinel.str, editor.size, rect_center(sentinel.rect), Text_Render_Options{.Center}, Color{1.0, 1.0, 1.0, 1.0})
		}
		
		sentinel = sentinel.next
	}
	
	frame_time_pos.y += text_line_advance(ui.font, editor.size)
	frame_time_rect = text_rect(ui.font, frame_time_text, editor.size, frame_time_pos, Text_Render_Options{.Center})
	render(frame_time_rect, Color{0.0, 0.0, 0.0, 0.0}, 0.0, 0.0, 1.0, Color{1, 0, 0, 1})
	render(ui.font, frame_time_text, editor.size, frame_time_pos, Text_Render_Options{.Ver_Top, .Center}, Color{1.0, 1.0, 1.0, 1.0})
	
	frame_time_pos.y += text_line_advance(ui.font, editor.size)
	frame_time_rect = text_rect(ui.font, frame_time_text, editor.size, frame_time_pos, Text_Render_Options{.Center})
	render(frame_time_rect, Color{0.0, 0.0, 0.0, 0.0}, 0.0, 0.0, 1.0, Color{1, 0, 0, 1})
	render(ui.font, frame_time_text, editor.size, frame_time_pos, Text_Render_Options{.Ver_Top, .Hor_Left}, Color{1.0, 1.0, 1.0, 1.0})
	
	frame_time_text = format_string("Mouse Pos: %.2f, %.2f", ui.mouse_pos.x, ui.mouse_pos.y)
	frame_time_pos.y += text_line_advance(ui.font, editor.size)*1.2
	frame_time_rect = text_rect(ui.font, frame_time_text, editor.size, frame_time_pos, Text_Render_Options{.Center})
	render(frame_time_rect, Color{0.0, 0.0, 0.0, 0.0}, 0.0, 0.0, 1.0, Color{1, 0, 0, 1})
	render(ui.font, frame_time_text, editor.size, frame_time_rect.xy, Text_Render_Options{.Center}, Color{1.0, 1.0, 1.0, 1.0})

	frame_time_text = format_string("Mouse dPos: %.2f, %.2f", ui.mouse_dpos.x, ui.mouse_dpos.y)
	frame_time_pos.y += text_line_advance(ui.font, editor.size)*1.2
	frame_time_rect = text_rect(ui.font, frame_time_text, editor.size, frame_time_pos, Text_Render_Options{.Center})
	render(frame_time_rect, Color{0.0, 0.0, 0.0, 0.0}, 0.0, 0.0, 1.0, Color{1, 0, 0, 1})
	render(ui.font, frame_time_text, editor.size, frame_time_rect.xy, Text_Render_Options{.Center}, Color{1.0, 1.0, 1.0, 1.0})

	ui_input_text := utf8.runes_to_string(ui.text[:], context.temp_allocator)
	render(ui.font, ui_input_text, editor.size, frame_time_pos + Vec2{0, ui.font.line_advance}, Text_Render_Options{.Center}, Color{1, 1, 1, 1})
*/
}
