package main

import "core:fmt"
import "core:log"
import "core:thread"
import "core:runtime"
import "vendor:glfw"
import gl "vendor:OpenGL"

import "events"
import "platform"
import "assets"
import "renderer"

Layer :: struct {
	using layer: platform.Layer,

	font: ^assets.Font,
	shader: ^assets.Shader,

	vao: renderer.GPU_Handle,
}

layer_on_attach :: proc(data: rawptr, app: ^platform.App) {
	editor := cast(^Layer)data
	assets.shader_load(&editor.shader, app, "shaders/default.glsl")
	assets.font_load(&editor.font, app, "fonts/OpenSans-Regular.ttf", 20, []assets.Font_Glyph_Range{assets.Font_Glyph_Range_Latin}, 256, 256)

	platform.app_finish_tasks(app)

	glyph := editor.font.glyphs['A']

	vertices := [24]f32{
		-0.5, -0.5, glyph.uv.x, glyph.uv.y, 
		0.5, -0.5, glyph.uv.z, glyph.uv.y,
		0.5, 0.5, glyph.uv.z, glyph.uv.w,
		0.5, 0.5, glyph.uv.z, glyph.uv.w,
		-0.5, 0.5, glyph.uv.x, glyph.uv.w,
		-0.5, -0.5, glyph.uv.x, glyph.uv.y,
		//-0.5, -0.5, 0, 0, 
		//0.5, -0.5, 1, 0,
		//0.5, 0.5, 1, 1,
		//0.5, 0.5, 1, 1,
		//-0.5, 0.5, 0, 1,
		//-0.5, -0.5, 0, 0,
	}

	vbo: u32
	gl.GenVertexArrays(1, &editor.vao)
	gl.BindVertexArray(editor.vao)
	gl.GenBuffers(1, &vbo)
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), cast(rawptr)&vertices[0], gl.STATIC_DRAW)
	gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 4 * size_of(f32), cast(uintptr)0)
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 4 * size_of(f32), cast(uintptr)(2*size_of(f32)))
	gl.EnableVertexAttribArray(1)
}

layer_on_detach :: proc(data: rawptr, app: ^platform.App) {
	editor := cast(^Layer)data
	assets.font_free(editor.font)
	assets.shader_free(editor.shader)
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

	if assets.font_validate(editor.font) && assets.shader_validate(editor.shader) {
		assets.shader_bind(editor.shader)
		gl.BindTexture(gl.TEXTURE_2D, editor.font.texture.handle)
		gl.ActiveTexture(gl.TEXTURE0)
		gl.BindVertexArray(editor.vao)
		gl.DrawArrays(gl.TRIANGLES, 0, 6)
	}
}
