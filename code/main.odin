package main

import "core:os"
import "core:log"
import "core:mem"
import "core:fmt"
import "core:runtime"
import "vendor:glfw"
import gl "vendor:OpenGL"

_main :: proc() {
	app := new(App)
	app_init(app, "Joodit", 1920, 1080)
	defer app_shutdown(app)

	renderer_init(app)
	defer renderer_free()

	ui_init(app)
	defer ui_free()

	app_push_layer(app, 
					new(Editor_Layer),
					editor_layer_on_attach,
					editor_layer_on_detach,
					editor_layer_on_update,
					editor_layer_on_render,
					editor_layer_on_event)

	for layer in app.layers {
		layer.on_attach(layer.data, app)
	}

	app_calc_dt(app)
	for app_running(app) {
		app_begin_frame(app)
		
		ui_begin()
		for i := 0; i < len(app.layers); i += 1 {
			layer := app.layers[i]
			layer.on_update(layer.data, app)
		}
		
		renderer_begin()
		for i := len(app.layers)-1; i >= 0; i -= 1 {
			layer := app.layers[i]
			layer.on_render(layer.data, app)
		}
		ui_end()
		renderer_end()

		app_end_frame(app)
	}
}

main :: proc() {	
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
    
	log_file, ok := os.open("log.txt", os.O_CREATE)
	
	logger := log.create_multi_logger(log.create_console_logger(), log.create_file_logger(log_file))
	context.logger = logger
	gcontext = context

	_main()

	os.close(log_file)
	log.destroy_multi_logger(&logger)

	for _, leak in track.allocation_map {
        log.debug(leak.location, "leaked ", leak.size, "bytes. ")
    }
    for bad_free in track.bad_free_array {
		log.debug(bad_free.location, "allocation ", bad_free.memory, " was freed badly.\n")
    }
}
