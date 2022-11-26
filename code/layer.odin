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

	tex: ^assets.Texture,

	size: f32, 
}

layer_on_attach :: proc(data: rawptr, app: ^platform.App) {
	editor := cast(^Layer)data

	assets.texture_load(&editor.tex, app, "textures/wood.png")

	editor.size = 30.0
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

	
	renderer.draw_text("Hello good world, SDF text rendering is working now! At last :>", {50, 400}, {1.0, 1.0, 1.0, 1.0}, editor.size)
	renderer.draw_rect({50, 400, 55, 405}, {1, 0, 0, 1})
	renderer.draw_texture(editor.tex, {100, 200, 200, 300}, {1, 1, 1, 1})
}
