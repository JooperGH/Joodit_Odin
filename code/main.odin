package main

import "core:os"
import "core:log"
import "core:mem"
import "core:fmt"
import "core:runtime"
import "vendor:glfw"
import gl "vendor:OpenGL"

import "platform"
import "renderer"

_main :: proc() {
	app := new(platform.App)
	platform.app_init(app, "Jedit", 1920, 1080)
	defer platform.app_shutdown(app)

	renderer.init()

	platform.app_push_layer(app, 
							new(Layer),
							layer_on_attach,
							layer_on_detach,
							layer_on_update,
							layer_on_render,
						    layer_on_event)

	for layer in app.layers {
		layer.on_attach(layer.data, app)
	}

	defer {		
		for layer in app.layers {
			layer.on_detach(layer.data, app)
			free(layer)
		}
	}

	platform.app_calc_dt(app)
	for platform.app_running(app) {
		platform.app_begin_frame(app)

		gl.ClearColor(0.1, 0.1, 0.1, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
		
		for i := 0; i < len(app.layers); i += 1 {
			layer := app.layers[i]
			layer.on_update(layer.data, app)
		}

		for i := len(app.layers)-1; i >= 0; i -= 1 {
			layer := app.layers[i]
			layer.on_render(layer.data, app)
		}
		
		platform.app_end_frame(app)
	}
}

main :: proc() {	
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
    
	log_file, ok := os.open("log.txt", os.O_CREATE | os.O_WRONLY)
	defer os.close(log_file)
	
	logger := log.create_multi_logger(log.create_console_logger(), log.create_file_logger(log_file))
    defer log.destroy_multi_logger(&logger)
	context.logger = logger
	platform.gcontext = context

	_main()

	for _, leak in track.allocation_map {
        log.debug(leak.location, "leaked ", leak.size, "bytes. ")
    }
    for bad_free in track.bad_free_array {
		log.debug(bad_free.location, "allocation ", bad_free.memory, " was freed badly.\n")
    }
}
