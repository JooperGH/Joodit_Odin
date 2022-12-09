package main

import "core:slice"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:math"
import "core:unicode/utf8"
import la "core:math/linalg/glsl"

import gl "vendor:OpenGL"

GPU_Handle :: u32

gl_renderer := Renderer{}

Vertex :: struct {
    pos_vec: [2]f32,
    tex_coord: [2]f32,
    color: Color,
    border_color: Color,
    tex_id: f32,
    mode: f32,
    rect: [4]f32,
    rect_params: [4]f32,
}

Quad :: [4]Vertex

Renderer :: struct {
    app: ^App,

	vao: u32,
	vbo: u32,
    ibo: u32,
    
    index_data_cap: u32,
    vertex_data_cap: u32,

    cached_texture_slot: u32,
    texture_slot: u32,
    texture_data: []u32,
    
    shader: ^Shader,

    dc: Draw,
}

renderer_init :: proc(app: ^App) {
    gl_renderer.app = app

    max_quads : u32 = 65536
    gl_renderer.index_data_cap = max_quads*6
    gl_renderer.vertex_data_cap = max_quads*4
    
    gl_renderer.cached_texture_slot = 0
    gl_renderer.texture_slot = 0
    gl_renderer.texture_data = make([]u32, 32)

    gl.GenVertexArrays(1, &gl_renderer.vao)
    gl.BindVertexArray(gl_renderer.vao)
    gl.GenBuffers(1, &gl_renderer.vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, gl_renderer.vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(Vertex) * int(gl_renderer.vertex_data_cap), nil, gl.DYNAMIC_DRAW)
    gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, size_of(Vertex), offset_of(Vertex, pos_vec))
    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, size_of(Vertex), offset_of(Vertex, tex_coord))
    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(2, 4, gl.FLOAT, gl.FALSE, size_of(Vertex), offset_of(Vertex, color))
    gl.EnableVertexAttribArray(2)
    gl.VertexAttribPointer(3, 4, gl.FLOAT, gl.FALSE, size_of(Vertex), offset_of(Vertex, border_color))
    gl.EnableVertexAttribArray(3)
    gl.VertexAttribPointer(4, 1, gl.FLOAT, gl.FALSE, size_of(Vertex), offset_of(Vertex, tex_id))
    gl.EnableVertexAttribArray(4)
    gl.VertexAttribPointer(5, 1, gl.FLOAT, gl.FALSE, size_of(Vertex), offset_of(Vertex, mode))
    gl.EnableVertexAttribArray(5)
    gl.VertexAttribPointer(6, 4, gl.FLOAT, gl.FALSE, size_of(Vertex), offset_of(Vertex, rect))
    gl.EnableVertexAttribArray(6)
    gl.VertexAttribPointer(7, 4, gl.FLOAT, gl.FALSE, size_of(Vertex), offset_of(Vertex, rect_params))
    gl.EnableVertexAttribArray(7)

    gl.GenBuffers(1, &gl_renderer.ibo)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, gl_renderer.ibo)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(u32) * int(gl_renderer.index_data_cap), nil, gl.DYNAMIC_DRAW)    
    gl.BindVertexArray(0)

    shader_load(&gl_renderer.shader, app, "shaders/default.glsl", false)
    
    if shader_validate(gl_renderer.shader) {
        shader_bind(gl_renderer.shader)
        samplers := make([]i32, 32, context.temp_allocator)
        for i := 0; i < 32; i += 1 {
            samplers[i] = i32(i)
        }
        shader_set(gl_renderer.shader, "u_textures", &samplers)
    }   

    draw_init(app)
}

renderer_free :: proc() {
    gl.DeleteVertexArrays(1, &gl_renderer.vao)
    gl.DeleteBuffers(1, &gl_renderer.vbo)
    gl.DeleteBuffers(1, &gl_renderer.ibo)

    delete(gl_renderer.texture_data)

    shader_free(&gl_renderer.shader)
}


renderer_begin :: proc() {
    draw_reset()
}

renderer_end :: proc() {
    if !shader_validate(gl_renderer.shader){
        return
    }

    gl.ClearColor(0.1, 0.1, 0.1, 1.0)
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

	gl.Enable(gl.BLEND)
	gl.Enable(gl.MULTISAMPLE)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)  

    shader_bind(gl_renderer.shader)
    proj := la.mat4Ortho3d(0, f32(gl_renderer.app.window_size.x), f32(gl_renderer.app.window_size.y), 0, -1.0, 1.0)
    shader_set(gl_renderer.shader, "u_proj", &proj)
    gl.BindVertexArray(gl_renderer.vao)
    renderer_process_draw_list_data()
}

renderer_process_draw_list_data :: proc() {
    for dcl in dc.dcls {
        for cmd_i : u32 = 0; cmd_i < u32(len(dcl.cmd_buf)); cmd_i += 1{
            cmd := &dcl.cmd_buf[cmd_i]
            
            // Do clip rect

            // Do textures
            for tex, i in cmd.textures {
                gl.BindTextureUnit(u32(i), tex)
            }

            gl.BindBuffer(gl.ARRAY_BUFFER, gl_renderer.vbo)
            gl.BufferSubData(gl.ARRAY_BUFFER, 
                             0,
                             size_of(Vertex)*int(4*cmd.idx_count/6), 
                             cast(rawptr)&dcl.vtx_buf[cmd.vtx_off])
            gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, gl_renderer.ibo)
            gl.BufferSubData(gl.ELEMENT_ARRAY_BUFFER,
                             0,
                             size_of(u32)*int(cmd.idx_count),
                             cast(rawptr)&dcl.idx_buf[cmd.idx_off])
            gl.DrawElements(gl.TRIANGLES, i32(cmd.idx_count), gl.UNSIGNED_INT, nil)
        }
    }
}