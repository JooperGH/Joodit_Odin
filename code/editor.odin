package main

import "core:fmt"
import "core:log"
import "core:thread"
import "core:runtime"
import "core:strings"
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

editor_layer_on_event :: proc(data: rawptr, app: ^App, e: ^Event) {
	editor := cast(^Editor_Layer)data
}

editor_layer_on_update :: proc(data: rawptr, app: ^App) {
	editor := cast(^Editor_Layer)data
}

editor_layer_on_render :: proc(data: rawptr, app: ^App) {
	editor := cast(^Editor_Layer)data

	if ui_button("Click").hovered {
		fmt.println("clicked!")
	}

	if ui.keys[Key_Code.A] {
		fmt.println(ui.mouse_pos)
	}


	frame_time_text := format_string("Frame Time: %.2f ms", app.dt*1000.0)
	frame_time_pos := Vec2{20, 20}
	frame_time_rect := text_rect(frame_time_text, editor.size, frame_time_pos, Text_Render_Options{.Center})
	render(frame_time_rect, Color{0.0, 0.0, 0.0, 0.0}, 10.0, 2.0, 3.0, Color{0, 0, 0, 1})
	render(frame_time_text, editor.size, frame_time_pos, Text_Render_Options{.Center}, Color{1.0, 1.0, 1.0, 1.0})
}
