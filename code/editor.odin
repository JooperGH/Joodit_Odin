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

	ui_spacer(5.0)
	ui_row_begin()
	ui_spacer(5.0)
	ui_push_flags({.Clickable, .Draggable})
	main_menu := ui_box("Main Menu", ui_widget_size(.Auto, 1.0), ui_widget_size(.Pixels, ui.font.line_advance+4.0))
	ui_pop_flags()
	ui_push_parent(main_menu)
	ui_spacer(2.0)
	ui_row_begin()
	ui_spacer(2.0)
	ui_button("File", ui_widget_size(.Pixels, ui.font.line_advance))
	ui_spacer(2.0)
	ui_button("Window", ui_widget_size(.Pixels, ui.font.line_advance))
	ui_spacer(2.0)
	ui_button("Panel", ui_widget_size(.Pixels, ui.font.line_advance))
	ui_spacer(2.0)
	ui_button("View", ui_widget_size(.Pixels, ui.font.line_advance))
	ui_spacer(2.0)
	ui_button("Control", ui_widget_size(.Pixels, ui.font.line_advance))
	ui_auto_spacer()
	ui_button("Font Size", ui_widget_size(.Pixels, ui.font.line_advance))
	ui_auto_spacer()
	w := ui_button("M", ui_widget_size(.Pixels, ui.font.line_advance), ui_widget_size(.Pixels, ui.font.line_advance))
	w.style.colors[.BgGradient0].g *= 2.0
	w.style.colors[.BgGradient1].g *= 2.0
	w.style.rounding = 0.5*ui.font.line_advance
	if w.i.left_clicked {
		app_toggle_fullscreen(app)
	}
	ui_spacer(2.0)
	w = ui_button("_", ui_widget_size(.Pixels, ui.font.line_advance), ui_widget_size(.Pixels, ui.font.line_advance))
	w.style.colors[.BgGradient0].rg *= 2.0
	w.style.colors[.BgGradient1].rg *= 2.0
	w.style.rounding = 0.5*ui.font.line_advance
	if w.i.left_clicked {
		app_minimize_window(app)
	}
	ui_spacer(2.0)
	w = ui_button("X", ui_widget_size(.Pixels, ui.font.line_advance), ui_widget_size(.Pixels, ui.font.line_advance))
	w.style.colors[.BgGradient0] = {0.55, 0.05, 0.05, 1.0}
	w.style.colors[.BgGradient1] = {0.6, 0.1, 0.1, 1.0}
	w.style.rounding = 0.5*ui.font.line_advance
	if w.i.left_clicked {
		app.running = false
	}
	ui_spacer(2.0)
	ui_row_end()
	ui_pop_parent()
	ui_spacer(5.0)
	ui_row_end()

	ui_spacer(5.0)
	ui_row_begin()
	ui_spacer(5.0)
	ui_box("Main Panel", ui_widget_size(.Auto), ui_widget_size(.Auto))
	ui_spacer(5.0)
	ui_row_end()
	ui_spacer(5.0)
	/*
	ui_row_begin()
	ui_spacer(5.0)
	ui_box("Panel 1", ui_widget_size(.Pixels, 952.5), ui_widget_size(.Pixels, 1025))
	ui_spacer(5.0)
	ui_box("Panel 2", ui_widget_size(.Pixels, 952.5), ui_widget_size(.Pixels, 1025))
	ui_spacer(5.0)
	ui_row_end()
	*/
/*
	ui_button("Window 1")
	ui_spacer(50.0)
	ui_row_begin()
	ui_button("Window 2")
	ui_button("Window 3")
	ui_row_end()
*/
	/*
	w := ui_bar("Menu Bar")

	ui_push_parent(w)
	ui_begin_row()
	
	ui_button("File")
	ui_button("Window")
	ui_button("Panel")
	ui_button("View")
	ui_button("Control")
	ui_spacer({50, 0})
	w = ui_slider_f32(format_string("Font Size: %.0f###FontSizeText", ui.font_size), &ui.font_size, 32.0, 50.0)
	ui_spacer({50, 0})
	//w.style.gradient = false
	//w.style.colors[.Bg].rgb *= 1.5
	//ui_push_parent(w)
	//ui_push_flags({.CenterX, .CenterY})
	//ui_text("Yuna fits in this box")
	//ui_pop_flags()
	//ui_pop_parent()

	w = ui_button("M")
	w.style.gradient = false
	w.style.colors[.Bg].g *= 2.0
	w.size[.X].kind = .PercentParent
	w.size[.X].value = 0.02
	if w.i.left_clicked {
		app_toggle_fullscreen(app)
	}
	w = ui_button("_")
	w.style.gradient = false
	w.style.colors[.Bg].rg *= 2.0
	w.size[.X].kind = .PercentParent
	w.size[.X].value = 0.02
	if w.i.left_clicked {
		app_minimize_window(app)
	}
	w = ui_button("X")
	w.style.gradient = false
	w.style.colors[.Bg] = {0.6, 0.1, 0.1, 1.0}
	w.size[.X].kind = .PercentParent
	w.size[.X].value = 0.02
	if w.i.left_clicked {
		app.running = false
	}
	ui_end_row()
	ui_pop_parent()

 /*
	w = ui_panel_space("Panel Space")

	ui_push_parent(w)

	w = ui_panel("Left Panel")
	if w.i.hovered {
		w.style.colors[.Border] = {1.0, 1.0, 0.0, 1.0}
	}

	ui_pop_parent()

	*/
	/*ui_push_parent(w)
	ui_text(format_string("%s###TextInput1", utf8.runes_to_string(ui.text[:], ui.temp_allocator)))
	ui_pop_parent()
	*/
	/*
	w = ui_panel("Right Panel")
	if w.i.hovered {
		w.style.colors[.Border] = {1.0, 1.0, 0.0, 1.0}
	}
	ui_push_parent(w)
	ui_text(format_string("%s###TextInput2", utf8.runes_to_string(ui.text[:], ui.temp_allocator)))
	ui_pop_parent()
	*/
	*/
}

editor_layer_on_render :: proc(data: rawptr, app: ^App) {
	editor := cast(^Editor_Layer)data

}