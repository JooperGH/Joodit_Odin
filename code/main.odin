package main

import "core:log"
import "vendor:glfw"

import "platform"
import "editor"

main :: proc() {
	context.logger = log.create_console_logger()
    
	app := new(platform.App)
	platform.app_init(app, "Jedit", 1920, 1080)
	defer platform.app_shutdown(app)
	

	platform.app_push_layer(app, 
							new(editor.Layer),
							editor.layer_on_attach,
							editor.layer_on_detach,
							editor.layer_on_update,
							editor.layer_on_render)

	for layer in app.layers {
		layer.on_attach(layer.data, app)
	}

	defer {		
		for layer in app.layers {
			layer.on_detach(layer.data, app)
		}
	}

	platform.app_calc_dt(app)
	for platform.app_running(app) {
		platform.app_begin_frame(app)

		for layer in app.layers {
			layer.on_update(layer.data, app)
		}

		for layer in app.layers {
			layer.on_render(layer.data, app)
		}
		
		platform.app_end_frame(app)
	}
}