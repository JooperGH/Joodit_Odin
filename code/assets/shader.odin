package assets

import "core:log"
import "core:fmt"
import "core:os"
import "core:thread"
import "core:strings"
import gl "vendor:OpenGL"

import "../renderer"
import "../platform"

Shader :: struct {
    path: string,
    src: string,

    id: renderer.GPU_Handle,
    load_state: Load_State,
}

Shader_Load_Task_Data :: struct {
    shader: ^^Shader,
    path: cstring,
}

shader_load :: proc(shader: ^^Shader, app: ^platform.App, path: cstring) {
    if !check_load_state(cast(rawptr)shader^, Shader, proc(data: rawptr) {
        shader_free(cast(^Shader)data)
    }) {
        return
    }

    log.debug("Shader load request at ", platform.app_time())

    shader^ = new(Shader)
    shader^.load_state = .Queued

    data := new(Shader_Load_Task_Data, context.allocator)
    data.shader = shader
    data.path = path
    platform.app_push_task(app, shader_load_task, cast(rawptr)data)    
}

shader_free :: proc(shader: ^Shader) {
    gl.DeleteProgram(shader.id)
    free(shader)
}

@(private)
shader_load_task :: proc(task: thread.Task) {
    task_data := cast(^Shader_Load_Task_Data)task.data

    src, ok := os.read_entire_file_from_filename(string(task_data.path), context.allocator)
    
    if ok  {
        shader := task_data.shader^
        shader.path = string(task_data.path)
        shader.src = strings.string_from_nul_terminated_ptr(&src[0], len(src))
        shader.load_state = .Loaded_And_Not_Uploaded
        log.debug("Shader load request succeeded at ", platform.app_time())
    } else {
        task_data.shader^.load_state = .Invalid
    }

    free(task_data, context.allocator)
}

shader_upload :: proc(shader: ^Shader) {
    if !shader_validate_data(shader) {
        log.error("Attempted to upload shader to GPU but data is not valid.")
        return
    }

    srcs: [2]string
    if !shader_preprocess(shader, &srcs) {
        shader.load_state = .Invalid
        return
    }

    vcstr := strings.clone_to_cstring(srcs[0], context.temp_allocator)
    fcstr := strings.clone_to_cstring(srcs[1], context.temp_allocator)
    
    vs, fs: u32
    success, length: i32

    vs = gl.CreateShader(gl.VERTEX_SHADER)
    gl.ShaderSource(vs, 1, &vcstr, nil)
    gl.CompileShader(vs)
    gl.GetShaderiv(vs, gl.COMPILE_STATUS, &success)
    if success == 0 {
        buf: [1024]u8
        gl.GetShaderInfoLog(vs, len(buf), nil, &buf[0])
        log.error(strings.string_from_nul_terminated_ptr(&buf[0], len(buf)))
    }
    
    fs = gl.CreateShader(gl.FRAGMENT_SHADER)
    gl.ShaderSource(fs, 1, &fcstr, nil)
    gl.CompileShader(fs)
    gl.GetShaderiv(fs, gl.COMPILE_STATUS, &success)
    if success == 0 {
        buf: [1024]u8
        gl.GetShaderInfoLog(fs, len(buf), nil, &buf[0])
        log.error(strings.string_from_nul_terminated_ptr(&buf[0], len(buf)))
    }
    
    id := gl.CreateProgram()
    gl.AttachShader(id, vs)
    gl.AttachShader(id, fs)
    gl.LinkProgram(id)

    gl.GetProgramiv(id, gl.LINK_STATUS, &success)
    if success == 0 {
        buf: [1024]u8
        gl.GetProgramInfoLog(id, len(buf), nil, &buf[0])
        log.error(strings.string_from_nul_terminated_ptr(&buf[0], len(buf)))
    }
    gl.DeleteShader(vs)
    gl.DeleteShader(fs)
    
    if success != 0 {
        shader.id = id
        shader.load_state = .Loaded_And_Uploaded
    } else {
        gl.DeleteProgram(id)
        shader.load_state = .Invalid
    }
}

shader_validate :: proc(shader: ^Shader) -> b32 {
    if shader == nil do return false
    if shader.load_state == .Invalid do return false

    if shader.load_state == .Unloaded || shader.load_state == .Queued {
        return false
    }

    if shader.load_state == .Loaded_And_Not_Uploaded {
        shader_upload(shader)
    }

    if shader.load_state == .Loaded_And_Uploaded  do return true

    return false
}

@(private)
shader_validate_data :: proc(shader: ^Shader) -> b32 {
    return len(shader.src) != 0
}

@(private)
shader_preprocess :: proc(shader: ^Shader, srcs: ^[2]string) -> b32 {
    src := strings.clone(shader.src, context.temp_allocator)
    
    offset_pre_vs := strings.index(src, "#vertex")
    offset_pre_fs := strings.index(src, "#fragment")

    if offset_pre_vs != -1 && offset_pre_fs != -1 {
        offset_to_vs := offset_pre_vs + len("#vertex")
        offset_to_fs := offset_pre_fs + len("#fragment")

        vs_src := shader.src[offset_to_vs:offset_pre_fs]
        fs_src := shader.src[offset_to_fs:]

        srcs^[0] = strings.clone(vs_src, context.temp_allocator)
        srcs^[1] = strings.clone(fs_src, context.temp_allocator)
        return true
    } else {
        log.error("Could not locate #vertex/#fragment in shader ", shader.path)
    }

    return false
}