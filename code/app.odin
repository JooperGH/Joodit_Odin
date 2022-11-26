package main

import "core:fmt"
import "core:runtime"
import "core:log"
import "core:strings"
import "core:thread"
import la "core:math/linalg/glsl"

import "vendor:glfw"
import gl "vendor:OpenGL"


gcontext: runtime.Context

App :: struct {
    title: string,
    width: i32,
    height: i32,
    dt: f32,

    pool: thread.Pool,

    event_callback: proc(app: ^App, e: ^Event),
    layers: [dynamic]^Layer,
    running: b32,
    last_time: f32,
    window: glfw.WindowHandle,
}

Event_Fn :: #type proc(rawptr, ^App, ^Event) -> b32

app_init :: proc(app: ^App, title: string, width: i32 = 1280, height: i32 = 720) {
    app.width = width
    app.height = height
    app.title = title
    app.layers = make([dynamic]^Layer, 0, 4)

    app.last_time = f32(glfw.GetTime())

    gl_major :: 4
    gl_minor :: 6
    
    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, gl_major)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, gl_minor)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
    glfw.WindowHint(glfw.DOUBLEBUFFER, 1)
    glfw.WindowHint(glfw.SAMPLES, 4)

	if glfw.Init() != 1 {
		log.error("Failed to initialize GLFW.")
		return
	}
    
    log.debug(log.Level.Debug, "Creating window...")
	app.window = glfw.CreateWindow(app.width, app.height, strings.clone_to_cstring(app.title, context.temp_allocator), nil, nil)
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
    
    thread.pool_init(&app.pool, context.allocator, 3)
    thread.pool_start(&app.pool)

    app.running = true
}

app_push_task :: proc(app: ^App, procedure: thread.Task_Proc, data: rawptr) {
    thread.pool_add_task(&app.pool, context.allocator, procedure, data)
}

app_finish_tasks :: proc(app: ^App) {
    thread.pool_finish(&app.pool)
    thread.pool_start(&app.pool)
}

app_shutdown :: proc(app: ^App) {
    for layer in app.layers {
        layer.on_detach(layer.data, app)
        free(layer)
    }

    delete(app.layers)
    thread.pool_join(&app.pool)
    thread.pool_destroy(&app.pool)
    glfw.DestroyWindow(app.window)
    glfw.Terminate()
    free(app)
}

app_running :: proc(app: ^App) -> b32 {
    return !glfw.WindowShouldClose(app.window) && app.running 
}

app_time :: proc() -> f32 {
    return f32(glfw.GetTime())
}

app_begin_frame :: proc(app: ^App) {
    event := app_update_start(app_time())
    app->event_callback(&event)
    glfw.PollEvents()
}

app_calc_dt :: proc(app: ^App) {
    new_time : f32 = f32(glfw.GetTime())
    app.dt = new_time - app.last_time
    app.last_time = new_time
}

app_end_frame :: proc(app: ^App) {
    event := app_update_end(app_time())
    app->event_callback(&event)
    event = app_render_start(app_time())
    app->event_callback(&event)
    glfw.SwapBuffers(app.window)
    event = app_render_end(app_time())
    app->event_callback(&event)
    app_calc_dt(app)
}

app_push_layer :: proc(app: ^App,
                  layer: ^Layer,
                  on_attach: proc(rawptr, ^App),
                  on_detach: proc(rawptr, ^App),
                  on_update: proc(rawptr, ^App),
                  on_render: proc(rawptr, ^App),
                  on_event: proc(rawptr, ^App, ^Event)) {
    layer.data = layer
    layer.on_attach = on_attach
    layer.on_detach = on_detach
    layer.on_update = on_update
    layer.on_render = on_render
    layer.on_event = on_event
    append(&app.layers, layer)
}

event_dispatch :: proc(data: rawptr, e: ^Event, app: ^App, $T: typeid, fn: Event_Fn) -> b32 {
    _, ok := e.type.(T)
    if ok {
        e.handled |= fn(data, app, e)
        return true
    }

    return false
}   

on_window_close :: proc(data: rawptr, app: ^App, e: ^Event) -> b32 {
    return true
}

on_window_resized :: proc(data: rawptr, app: ^App, e: ^Event) -> b32 {
    return true
}

on_window_moved :: proc(data: rawptr, app: ^App, e: ^Event) -> b32 {
    return true
}

on_window_focus :: proc(data: rawptr, app: ^App, e: ^Event) -> b32 {
    return true
}

on_event :: proc(app: ^App, e: ^Event) {
    event_dispatch(nil, e, app, Window_Close_Event, on_window_close)
    event_dispatch(nil, e, app, Window_Resized_Event, on_window_resized)
    event_dispatch(nil, e, app, Window_Moved_Event, on_window_moved)
    event_dispatch(nil, e, app, Window_Focus_Event, on_window_focus)

    for layer in app.layers {
        if e.handled {
            break
        }
        
        layer.on_event(layer.data, app, e)
    }
}

@(private)
key_callback :: proc "cdecl" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
    context = gcontext
    app := transmute(^App)glfw.GetWindowUserPointer(window)

    event := Event{}
    switch action {
        case glfw.PRESS: event = key_pressed(key, 0)
        case glfw.REPEAT: event = key_pressed(key, 1)
        case glfw.RELEASE: event = key_released(key, 0)
    }
    app->event_callback(&event)
}

@(private)
scroll_callback :: proc "cdecl" (window: glfw.WindowHandle, xpos, ypos: f64) {
    context = gcontext
    app := transmute(^App)glfw.GetWindowUserPointer(window)
    event := mouse_scrolled(la.vec2{f32(xpos), f32(ypos)})
    app->event_callback(&event)
}

@(private)
button_callback :: proc "cdecl" (window: glfw.WindowHandle, button, action, mods: i32) {
    context = gcontext
    app := transmute(^App)glfw.GetWindowUserPointer(window)

    event := Event{}
    switch action {
        case glfw.PRESS: event = mouse_pressed(button)
        case glfw.RELEASE: event = mouse_released(button)
    }
    app->event_callback(&event)
}

@(private)
cursor_pos_callback :: proc "cdecl" (window: glfw.WindowHandle, xpos, ypos: f64) {
    context = gcontext
    app := transmute(^App)glfw.GetWindowUserPointer(window)
    event := mouse_moved(la.vec2{f32(xpos), f32(ypos)})
    app->event_callback(&event)
}

@(private)
window_size_callback :: proc "cdecl" (window: glfw.WindowHandle, width, height: i32) {
    context = gcontext
    app := transmute(^App)glfw.GetWindowUserPointer(window)
    event := window_resize(la.vec2{f32(width), f32(height)})
    app->event_callback(&event)
}

@(private)
window_pos_callback :: proc "cdecl" (window: glfw.WindowHandle, width, height: i32) {
    context = gcontext
    app := transmute(^App)glfw.GetWindowUserPointer(window)
    event := window_moved(la.vec2{f32(width), f32(height)})
    app->event_callback(&event)
}

@(private)
window_close_callback :: proc "cdecl" (window: glfw.WindowHandle) {
    context = gcontext
    app := transmute(^App)glfw.GetWindowUserPointer(window)
    event := window_close(0)
    app->event_callback(&event)
}

@(private)
window_focus_callback :: proc "cdecl" (window: glfw.WindowHandle, iconified: i32) {
    context = gcontext
    app := transmute(^App)glfw.GetWindowUserPointer(window)
    event := window_focus(b32(iconified))
    app->event_callback(&event)
}