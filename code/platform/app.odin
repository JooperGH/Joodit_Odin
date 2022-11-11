package platform

import "core:log"
import "core:strings"
import "vendor:glfw"
import gl "vendor:OpenGL"

App :: struct {
    title: string,
    width: i32,
    height: i32,
    dt: f32,

    layers: [dynamic]^Layer,
    running: b32,
    last_time: f32,
    window: glfw.WindowHandle,
}

app_init :: proc(app: ^App, title: string, width: i32 = 1280, height: i32 = 720) {
    app.width = width
    app.height = height
    app.title = title
    app.layers = make([dynamic]^Layer, 0, 4)

    app.last_time = f32(glfw.GetTime())

    gl_major :: 3
    gl_minor :: 3
    
    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, gl_major)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, gl_minor)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

	if glfw.Init() != 1 {
		log.error("Failed to initialize GLFW.")
		return
	}
    
    log.debug(log.Level.Debug, "Creating window...")
	app.window = glfw.CreateWindow(app.width, app.height, strings.clone_to_cstring(app.title), nil, nil)
    if app.window == nil {
		log.error("Failed to create window.")
		return
	}

	glfw.MakeContextCurrent(app.window)
	glfw.SwapInterval(1)

	gl.load_up_to(gl_major, gl_minor, glfw.gl_set_proc_address)
    
    app.running = true
}

app_shutdown :: proc(app: ^App) {
    glfw.DestroyWindow(app.window)
    glfw.Terminate()
}

app_running :: proc(app: ^App) -> b32 {
    return !glfw.WindowShouldClose(app.window) && app.running 
}

app_begin_frame :: proc(app: ^App) {
    glfw.PollEvents()
}

app_calc_dt :: proc(app: ^App) {
    new_time : f32 = f32(glfw.GetTime())
    app.dt = new_time - app.last_time
    app.last_time = new_time
}

app_end_frame :: proc(app: ^App) {
    glfw.SwapBuffers(app.window)
    app_calc_dt(app)
}

app_push_layer :: proc(app: ^App,
                  layer: ^Layer,
                  on_attach: proc(rawptr, ^App),
                  on_detach: proc(rawptr, ^App),
                  on_update: proc(rawptr, ^App),
                  on_render: proc(rawptr, ^App)) {
    layer.data = layer
    layer.on_attach = on_attach
    layer.on_detach = on_detach
    layer.on_update = on_update
    layer.on_render = on_render
    append(&app.layers, layer)
}