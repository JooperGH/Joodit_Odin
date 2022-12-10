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
}

editor_layer_on_attach :: proc(data: rawptr, app: ^App) {
	editor := cast(^Editor_Layer)data
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
	w := ui_bar("Menu Bar")

	ui_push_parent(w)
	ui_begin_row()
	
	ui_button("File")
	ui_button("Window")
	ui_button("Panel")
	ui_button("View")
	ui_button("Control")
	ui_spacer()
	w = ui_slider_f32(format_string("Font Size: %.0f###FontSizeText", ui.font_size), &ui.font_size, 32.0, 50.0)
	
	ui_spacer()
	w.style.gradient = false
	w.style.colors[.Bg].rgb *= 1.5
	ui_push_parent(w)
	ui_push_flags({.CenterX, .CenterY})
	ui_text("Yuna fits in this box")
	ui_pop_flags()
	ui_pop_parent()

	w = ui_button("M")
	w.style.gradient = false
	w.style.colors[.Bg].g *= 2.0
	w.semantic_sizes[.X].kind = .PercentOfParent
	w.semantic_sizes[.X].value = 0.02
	if w.i.left_clicked {
		app_toggle_fullscreen(app)
	}
	w = ui_button("_")
	w.style.gradient = false
	w.style.colors[.Bg].rg *= 2.0
	w.semantic_sizes[.X].kind = .PercentOfParent
	w.semantic_sizes[.X].value = 0.02
	if w.i.left_clicked {
		app_minimize_window(app)
	}
	w = ui_button("X")
	w.style.gradient = false
	w.style.colors[.Bg] = {0.6, 0.1, 0.1, 1.0}
	w.semantic_sizes[.X].kind = .PercentOfParent
	w.semantic_sizes[.X].value = 0.02
	if w.i.left_clicked {
		app.running = false
	}
	ui_end_row()
	ui_pop_parent()
	
	w = ui_panel("Main Panel")
	if w.i.hovered {
		w.style.colors[.Border] = {1.0, 1.0, 0.0, 1.0}
	}
	ui_push_parent(w)
	ui_text(format_string("%s###TextInput1", utf8.runes_to_string(ui.text[:], ui.temp_allocator)))
	ui_pop_parent()
}

editor_layer_on_render :: proc(data: rawptr, app: ^App) {
	editor := cast(^Editor_Layer)data

}
