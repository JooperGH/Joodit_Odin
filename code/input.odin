package main

import "vendor:glfw"

input_key_down :: proc(app: ^App, key_code: i32) -> b32 {
    state := glfw.GetKey(app.window, key_code)
    return state == glfw.PRESS || state == glfw.REPEAT
}

input_key_pressed :: proc(app: ^App, key_code: i32) -> b32 {
    state := glfw.GetKey(app.window, key_code)
    return state == glfw.PRESS
}

input_key_release :: proc(app: ^App, key_code: i32) -> b32 {
    state := glfw.GetKey(app.window, key_code)
    return state == glfw.RELEASE
}

input_mouse_pressed :: proc(app: ^App, key_code: i32) -> b32 {
    state := glfw.GetMouseButton(app.window, key_code)
    return state == glfw.PRESS
}

input_mouse_released :: proc(app: ^App, key_code: i32) -> b32 {
    state := glfw.GetMouseButton(app.window, key_code)
    return state == glfw.RELEASE
}

input_mouse_pos :: proc(app: ^App) -> Vec2 {
    x, y := glfw.GetCursorPos(app.window)
    return Vec2{f32(x), f32(app.height)-f32(y)}
}
