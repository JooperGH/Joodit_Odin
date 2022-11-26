package assets

import "core:log"
import "core:fmt"
import "core:os"
import "core:thread"
import "core:strings"
import "core:strconv"
import gl "vendor:OpenGL"
import la "core:math/linalg/glsl"

import "../platform"

Shader :: struct {
    path: string,
    src: string,

    uniform_names: [dynamic]string,
    uniform_locs: map[string]i32,

    handle: u32,
    load_state: Load_State,
}

Shader_Load_Task_Data :: struct {
    shader: ^^Shader,
    path: cstring,
}

shader_load :: proc(shader: ^^Shader, app: ^platform.App, path: cstring, threaded: bool = true) {
    if !check_load_state(cast(rawptr)shader^, Shader, proc(data: rawptr) {
        shader := cast(^Shader)data
        shader_free(&shader)
    }) {
        return
    }

    log.debug("Shader load request at ", platform.app_time())

    shader^ = new(Shader)
    shader^.load_state = .Queued

    data := new(Shader_Load_Task_Data, context.allocator)
    data.shader = shader
    data.path = path
    
    if threaded {
        platform.app_push_task(app, shader_load_task, cast(rawptr)data)    
    } else {
        ttask := thread.Task{}
        ttask.allocator = context.allocator
        ttask.data = cast(rawptr)data
        ttask.user_index = context.user_index
        shader_load_task(ttask)
    }
}

shader_bind :: proc(shader: ^Shader) {
    gl.UseProgram(shader.handle)
}

shader_unbind :: proc(shader: ^Shader) {
    gl.UseProgram(0)
}

shader_reload :: proc(shader: ^^Shader, app: ^platform.App) {
    log.debug("Shader reload request at ", platform.app_time())
    path := strings.clone_to_cstring(shader^.path, context.temp_allocator)
    shader_free(shader)
    shader_load(shader, app, path)
}

shader_set :: proc{shader_set_i32, 
                   shader_set_u32, 
                   shader_set_f32,
                   shader_set_vec2,
                   shader_set_vec3,
                   shader_set_vec4,
                   shader_set_mat4,
                   shader_set_veci}

shader_set_i32 :: proc(shader: ^Shader, name: cstring, value: i32) {
    loc := shader.uniform_locs[strings.clone_from_cstring(name, context.temp_allocator)]
    gl.Uniform1i(loc, value)
}

shader_set_u32 :: proc(shader: ^Shader, name: cstring, value: u32) {
    loc := shader.uniform_locs[strings.clone_from_cstring(name, context.temp_allocator)]
    gl.Uniform1ui(loc, value)
}

shader_set_f32 :: proc(shader: ^Shader, name: cstring, value: f32) {
    loc := shader.uniform_locs[strings.clone_from_cstring(name, context.temp_allocator)]
    gl.Uniform1f(loc, value)
}

shader_set_vec2 :: proc(shader: ^Shader, name: cstring, value: ^la.vec2) {
    using la
    loc := shader.uniform_locs[strings.clone_from_cstring(name, context.temp_allocator)]
    gl.Uniform2fv(loc, 1, &value[0])
}

shader_set_vec3 :: proc(shader: ^Shader, name: cstring, value: ^la.vec3) {
    using la
    loc := shader.uniform_locs[strings.clone_from_cstring(name, context.temp_allocator)]
    gl.Uniform3fv(loc, 1, &value[0])
}

shader_set_vec4 :: proc(shader: ^Shader, name: cstring, value: ^la.vec4) {
    using la
    loc := shader.uniform_locs[strings.clone_from_cstring(name, context.temp_allocator)]
    gl.Uniform4fv(loc, 1, &value[0])
}

shader_set_mat4 :: proc(shader: ^Shader, name: cstring, value: ^la.mat4) {
    using la
    loc := shader.uniform_locs[strings.clone_from_cstring(name, context.temp_allocator)]
    gl.UniformMatrix4fv(loc, 1, gl.FALSE, &value[0,0])
}

shader_set_veci :: proc(shader: ^Shader, name: cstring, value: ^[]i32) {
    using la
    loc := shader.uniform_locs[strings.clone_from_cstring(name, context.temp_allocator)]
    gl.Uniform1iv(loc, i32(len(value)), &value[0])
}

shader_free :: proc(shader: ^^Shader) {
    if shader^ != nil {
        for i := 0; i < len(shader^.uniform_names); i += 1 {
            delete(shader^.uniform_names[i])
        }
        delete(shader^.uniform_names)

        delete(shader^.uniform_locs)
        gl.DeleteProgram(shader^.handle)
        free(shader^)
        shader^ = nil
    }
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
        shader.uniform_locs = make(map[string]i32)
        for name in shader.uniform_names {
            shader.uniform_locs[name] = gl.GetUniformLocation(id, strings.clone_to_cstring(name, context.temp_allocator))
        }

        shader.handle = id
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

@(private)
shader_validate_data :: proc(shader: ^Shader) -> b32 {
    return len(shader.src) != 0
}

@(private)
shader_preprocess_uniform_names :: proc(shader: ^Shader, src: string) {
    if shader.uniform_names == nil {
        shader.uniform_names = make([dynamic]string)
    }

    cs := src
    at_next := strings.index(cs, "uniform")
    for at_next != -1 {
        cs = cs[at_next:]
        at_endl := strings.index(cs, ";")
        line := cs[:at_endl]
        split := strings.split(line, " ", context.temp_allocator)

        uniform_name := split[2]
        open_bracket_at := strings.index(uniform_name, "[") 
        if open_bracket_at != -1 {
            // Append array name
            append(&shader.uniform_names, strings.clone_from(uniform_name[:open_bracket_at]))

            // Append sub location names
            /*
            close_bracket_at := strings.index(uniform_name, "]")
            if close_bracket_at != 1 {
                number_string := uniform_name[open_bracket_at+1:close_bracket_at]
                array_size, ok := strconv.parse_int(number_string)
                if ok {
                    array_name := uniform_name[:open_bracket_at]
                    for i := 0; i < array_size; i += 1 {
                        b := strings.builder_make(context.temp_allocator)
                        strings.write_string(&b, array_name)
                        strings.write_string(&b, "[")
                        strings.write_int(&b, i)
                        strings.write_string(&b, "]")
                        append(&shader.uniform_names, strings.clone_from(strings.to_string(b)))
                    }
                } else {
                    log.error("Shader has wrong array size.")
                    return
                }
            }
            */
        } else {
            append(&shader.uniform_names, strings.clone_from(split[2]))
        }


        cs = cs[at_endl:]
        at_next = strings.index(cs, "uniform")
    }
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

        shader_preprocess_uniform_names(shader, vs_src)
        shader_preprocess_uniform_names(shader, fs_src)

        srcs^[0] = strings.clone(vs_src, context.temp_allocator)
        srcs^[1] = strings.clone(fs_src, context.temp_allocator)
        return true
    } else {
        log.error("Could not locate #vertex/#fragment in shader ", shader.path)
    }

    return false
}