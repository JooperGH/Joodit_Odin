package platform

import "vendor:glfw"
import la "core:math/linalg/glsl"

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

input_mouse_pos :: proc(app: ^App) -> la.vec2 {
    x, y := glfw.GetCursorPos(app.window)
    return la.vec2{f32(x), f32(y)}
}
