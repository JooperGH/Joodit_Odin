package layer

import "core:fmt"
import "core:log"
import "core:thread"
import "core:runtime"
import "vendor:glfw"
import gl "vendor:OpenGL"

import "../events"
import "../platform"
import "../assets"

Layer :: struct {
	using layer: platform.Layer,

	font: ^assets.Font,
}

layer_on_attach :: proc(data: rawptr, app: ^platform.App) {
	editor := cast(^Layer)data
}

layer_on_detach :: proc(data: rawptr, app: ^platform.App) {
	editor := cast(^Layer)data
	free(editor.font)
	free(editor)
}

on_mouse_moved :: proc(data: rawptr, app: ^platform.App, e: ^events.Event) -> b32 {
	editor := cast(^Layer)data
	return false
}

on_key_pressed :: proc(data: rawptr, app: ^platform.App, e: ^events.Event) -> b32 {
	editor := cast(^Layer)data
	kp := e.type.(events.Key_Pressed_Event)

	if kp.key_code == glfw.KEY_P {
		assets.font_load(&editor.font, app, "fonts/OpenSans-Regular.ttf", 20)
	}
	
	return false
}

layer_on_event :: proc(data: rawptr, app: ^platform.App, e: ^events.Event) {
	editor := cast(^Layer)data
	platform.event_dispatch(data, e, app, events.Mouse_Moved_Event, on_mouse_moved)
	platform.event_dispatch(data, e, app, events.Key_Pressed_Event, on_key_pressed)
}

layer_on_update :: proc(data: rawptr, app: ^platform.App) {
	editor := cast(^Layer)data

	if assets.font_validate(editor.font) {
		log.debug(editor.font.load_state)
	} 
}

layer_on_render :: proc(data: rawptr, app: ^platform.App) {
	editor := cast(^Layer)data
}
