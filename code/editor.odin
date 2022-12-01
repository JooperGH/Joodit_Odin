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

	i := ui_bar("Menu Bar")
	i.widget.style.gradient = false

	ui_push_parent(i.widget)
	ui_push_flags({.FillX})
	
	ui_button("File")
	ui_button("Window")
	ui_button("Panel")
	ui_button("View")
	ui_button("Control")
	i = ui_button("U")
	if i.left_clicked {
		ui.font_size += 1.0
	}
	
	i = ui_button("D")
	if i.left_clicked {
		ui.font_size -= 1.0
	}

	ui_spacer()	
	ui_text(format_string("Font Size: %d###FontSizeText", i32(ui.font_size)))
	i = ui_button("M")
	i.widget.style.gradient = false
	i.widget.style.colors[.Bg].g *= 2.0
	i = ui_button("_")
	i.widget.style.gradient = false
	i.widget.style.colors[.Bg].rg *= 2.0
	i = ui_button("X")
	i.widget.style.gradient = false
	i.widget.style.colors[.Bg] = {0.6, 0.1, 0.1, 1.0}
	if i.left_clicked {
		app.running = false
	}
	ui_pop_flags()
	ui_pop_parent()

	i = ui_panel("Main Panel")
	ui_push_parent(i.widget)
	ui_push_flags({.FillX})
	ui_text(format_string("%s###TextInput", utf8.runes_to_string(ui.text[:], ui.temp_allocator)))
	ui_pop_flags()
	ui_pop_parent()

}

editor_layer_on_render :: proc(data: rawptr, app: ^App) {
	editor := cast(^Editor_Layer)data
}
