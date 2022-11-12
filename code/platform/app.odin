package platform

import "core:fmt"
import "core:runtime"
import "core:log"
import "core:strings"
import la "core:math/linalg/glsl"

import "vendor:glfw"
import gl "vendor:OpenGL"

import "../events"

App :: struct {
    title: string,
    width: i32,
    height: i32,
    dt: f32,

    event_callback: proc(app: ^App, e: ^events.Event),
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

    glfw.SetWindowSizeCallback(app.window, window_size_callback)
    glfw.SetKeyCallback(app.window, key_callback)
    glfw.SetMouseButtonCallback(app.window, button_callback)
    glfw.SetCursorPosCallback(app.window, cursor_pos_callback)
    glfw.SetScrollCallback(app.window, scroll_callback)
    glfw.SetWindowPosCallback(app.window, window_pos_callback)
    glfw.SetWindowCloseCallback(app.window, window_close_callback)
    glfw.SetWindowFocusCallback(app.window, window_focus_callback)

    glfw.SetWindowUserPointer(app.window, rawptr(app))
    app.event_callback = on_event

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

app_time :: proc() -> f32 {
    return f32(glfw.GetTime())
}

app_begin_frame :: proc(app: ^App) {
    event := events.app_update_start(app_time())
    app->event_callback(&event)
    glfw.PollEvents()
}

app_calc_dt :: proc(app: ^App) {
    new_time : f32 = f32(glfw.GetTime())
    app.dt = new_time - app.last_time
    app.last_time = new_time
}

app_end_frame :: proc(app: ^App) {
    event := events.app_update_end(app_time())
    app->event_callback(&event)
    event = events.app_render_start(app_time())
    app->event_callback(&event)
    glfw.SwapBuffers(app.window)
    event = events.app_render_end(app_time())
    app->event_callback(&event)
    app_calc_dt(app)
}

app_push_layer :: proc(app: ^App,
                  layer: ^Layer,
                  on_attach: proc(rawptr, ^App),
                  on_detach: proc(rawptr, ^App),
                  on_update: proc(rawptr, ^App),
                  on_render: proc(rawptr, ^App),
                  on_event: proc(rawptr, ^events.Event, ^App)) {
    layer.data = layer
    layer.on_attach = on_attach
    layer.on_detach = on_detach
    layer.on_update = on_update
    layer.on_render = on_render
    layer.on_event = on_event
    append(&app.layers, layer)
}

event_dispatch :: proc(data: rawptr, app: ^App, e: ^events.Event, $T: typeid, fn: proc(rawptr, ^events.Event, ^App) -> b32) -> b32 {
    _, ok := e.type.(T)
    if ok {
        e.handled |= fn(data, e, app)
        return true
    }

    return false
}   

on_window_close :: proc(data: rawptr, e: ^events.Event, app: ^App) -> b32 {
    return true
}

on_window_resized :: proc(data: rawptr, e: ^events.Event, app: ^App) -> b32 {
    return true
}

on_window_moved :: proc(data: rawptr, e: ^events.Event, app: ^App) -> b32 {
    return true
}

on_window_focus :: proc(data: rawptr, e: ^events.Event, app: ^App) -> b32 {
    fmt.println(e)
    return true
}

on_event :: proc(app: ^App, e: ^events.Event) {
    event_dispatch(nil, app, e, events.Window_Close_Event, on_window_close)
    event_dispatch(nil, app, e, events.Window_Resized_Event, on_window_resized)
    event_dispatch(nil, app, e, events.Window_Moved_Event, on_window_moved)
    event_dispatch(nil, app, e, events.Window_Focus_Event, on_window_focus)

    for layer in app.layers {
        if e.handled {
            break
        }
        
        layer.on_event(layer.data, e, app)
    }
}

@(private)
key_callback :: proc "cdecl" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
    context = runtime.default_context()
    app := transmute(^App)glfw.GetWindowUserPointer(window)

    event := events.Event{}
    switch action {
        case glfw.PRESS: event = events.key_pressed(key, 0)
        case glfw.REPEAT: event = events.key_pressed(key, 1)
        case glfw.RELEASE: event = events.key_released(key, 0)
    }
    app->event_callback(&event)
}

@(private)
scroll_callback :: proc "cdecl" (window: glfw.WindowHandle, xpos, ypos: f64) {
    context = runtime.default_context()
    app := transmute(^App)glfw.GetWindowUserPointer(window)
    event := events.mouse_scrolled(la.vec2{f32(xpos), f32(ypos)})
    app->event_callback(&event)
}

@(private)
button_callback :: proc "cdecl" (window: glfw.WindowHandle, button, action, mods: i32) {
    context = runtime.default_context()
    app := transmute(^App)glfw.GetWindowUserPointer(window)

    event := events.Event{}
    switch action {
        case glfw.PRESS: event = events.mouse_pressed(button)
        case glfw.RELEASE: event = events.mouse_released(button)
    }
    app->event_callback(&event)
}

@(private)
cursor_pos_callback :: proc "cdecl" (window: glfw.WindowHandle, xpos, ypos: f64) {
    context = runtime.default_context()
    app := transmute(^App)glfw.GetWindowUserPointer(window)
    event := events.mouse_moved(la.vec2{f32(xpos), f32(ypos)})
    app->event_callback(&event)
}

@(private)
window_size_callback :: proc "cdecl" (window: glfw.WindowHandle, width, height: i32) {
    context = runtime.default_context()
    app := transmute(^App)glfw.GetWindowUserPointer(window)
    event := events.window_resize(la.vec2{f32(width), f32(height)})
    app->event_callback(&event)
}

@(private)
window_pos_callback :: proc "cdecl" (window: glfw.WindowHandle, width, height: i32) {
    context = runtime.default_context()
    app := transmute(^App)glfw.GetWindowUserPointer(window)
    event := events.window_moved(la.vec2{f32(width), f32(height)})
    app->event_callback(&event)
}

@(private)
window_close_callback :: proc "cdecl" (window: glfw.WindowHandle) {
    context = runtime.default_context()
    app := transmute(^App)glfw.GetWindowUserPointer(window)
    event := events.window_close(0)
    app->event_callback(&event)
}

@(private)
window_focus_callback :: proc "cdecl" (window: glfw.WindowHandle, iconified: i32) {
    context = runtime.default_context()
    app := transmute(^App)glfw.GetWindowUserPointer(window)
    event := events.window_focus(b32(iconified))
    app->event_callback(&event)
}