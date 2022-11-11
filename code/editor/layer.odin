package layer

import "../platform"

import "core:log"
import "vendor:glfw"
import gl "vendor:OpenGL"

Layer :: struct {
	using layer: platform.Layer,
}

layer_on_attach :: proc(data: rawptr, app: ^platform.App) {
	editor := transmute(^Layer)data
	log.debug("On Attach!")
}

layer_on_detach :: proc(data: rawptr, app: ^platform.App) {
	editor := transmute(^Layer)data
	log.debug("On Detach!")
}

layer_on_update :: proc(data: rawptr, app: ^platform.App) {
	editor := transmute(^Layer)data
	
	if platform.input_key_down(app, glfw.KEY_P) {
		log.debug("On Update")
	}
}

layer_on_render :: proc(data: rawptr, app: ^platform.App) {
	editor := transmute(^Layer)data

    gl.ClearColor(0.1, 0.1, 0.1, 1.0)
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
}
