package main

import "core:fmt"
import "core:log"
import "core:thread"
import "core:runtime"
import "vendor:glfw"
import gl "vendor:OpenGL"
import la "core:math/linalg/glsl"

import "events"
import "platform"
import "assets"
import "renderer"

Layer :: struct {
	using layer: platform.Layer,
}

layer_on_attach :: proc(data: rawptr, app: ^platform.App) {
	editor := cast(^Layer)data
}

layer_on_detach :: proc(data: rawptr, app: ^platform.App) {
	editor := cast(^Layer)data
	free(editor)
}

on_mouse_moved :: proc(data: rawptr, app: ^platform.App, e: ^events.Event) -> b32 {
	editor := cast(^Layer)data
	return false
}

on_key_pressed :: proc(data: rawptr, app: ^platform.App, e: ^events.Event) -> b32 {
	editor := cast(^Layer)data
	kp := e.type.(events.Key_Pressed_Event)

	return false
}

layer_on_event :: proc(data: rawptr, app: ^platform.App, e: ^events.Event) {
	editor := cast(^Layer)data
	platform.event_dispatch(data, e, app, events.Mouse_Moved_Event, on_mouse_moved)
	platform.event_dispatch(data, e, app, events.Key_Pressed_Event, on_key_pressed)
}

layer_on_update :: proc(data: rawptr, app: ^platform.App) {
	editor := cast(^Layer)data
}

layer_on_render :: proc(data: rawptr, app: ^platform.App) {
	editor := cast(^Layer)data

	renderer.draw_text("Hello good world, SDF text rendering is working now! At last :>", {50, 400}, {1.0, 0.0, 1.0, 1.0}, 30.0)
}
