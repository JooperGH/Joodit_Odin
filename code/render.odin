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
    color: [4]f32,
    border_color: [4]f32,
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
    
    index_count: i32,
    vertex_data_at: u32,
    vertex_data_cap: u32,
    vertex_data: []Vertex,
    
    cached_texture_slot: u32,
    texture_slot: u32,
    texture_data: []u32,
    
    shader: ^Shader,
}

renderer_init :: proc(app: ^App) {
    gl_renderer.app = app

    max_quads : u32 = 65536
    gl_renderer.index_count = 0
    gl_renderer.vertex_data_at = 0
    gl_renderer.vertex_data_cap = max_quads*4
    gl_renderer.vertex_data = make([]Vertex, gl_renderer.vertex_data_cap)
    
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

    index_data := renderer_generate_index_data(max_quads)
    gl.GenBuffers(1, &gl_renderer.ibo)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, gl_renderer.ibo)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, int(size_of(u32) * max_quads * 6), cast(rawptr)&index_data[0], gl.STATIC_DRAW)    
    delete(index_data)
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
}

renderer_free :: proc() {
    gl.DeleteVertexArrays(1, &gl_renderer.vao)
    gl.DeleteBuffers(1, &gl_renderer.vbo)
    gl.DeleteBuffers(1, &gl_renderer.ibo)

    delete(gl_renderer.vertex_data)
    delete(gl_renderer.texture_data)

    shader_free(&gl_renderer.shader)
}

@(private)
renderer_add_quad :: proc(v: ^[4]Vertex) {
    if gl_renderer.vertex_data_at + 4 >= gl_renderer.vertex_data_cap {
        log.error("Renderer reached quad limit!")
        return
    }
    
    gl_renderer.vertex_data[gl_renderer.vertex_data_at] = v[0]
    gl_renderer.vertex_data[gl_renderer.vertex_data_at+1] = v[1]
    gl_renderer.vertex_data[gl_renderer.vertex_data_at+2] = v[2]
    gl_renderer.vertex_data[gl_renderer.vertex_data_at+3] = v[3]

    gl_renderer.vertex_data_at += 4
    gl_renderer.index_count += 6
}

render :: proc{ render_rect, 
                render_rect_gradient,
                render_rect_single_fill_single_border_color,
                render_rect_gradient_single_border_color,
                render_rect_gradient_single_fill_color,
                render_rect_no_border_no_rounding,
                render_rect_no_border_no_rounding_gradient,
                render_rect_no_border_no_rounding_single_color,
                render_text,
                render_texture}

render_rect_no_border_no_rounding :: proc(rect: Rect, colors: [4]Color) {
    render_rect(rect, colors, 0, 0, 0, {})
}

render_rect_no_border_no_rounding_gradient :: proc(rect: Rect, colors: [2]Color) {
    render_rect(rect, {colors[1], colors[1], colors[0], colors[0]}, 0, 0, 0, {})
}

render_rect_no_border_no_rounding_single_color :: proc(rect: Rect, color: Color) {
    render_rect(rect, {color, color, color, color}, 0, 0, 0, {})
}

render_rect_single_fill_single_border_color :: proc(rect: Rect, color: Color, roundness: f32, softness: f32, border_thickness: f32, border_color: Color) {
    render_rect(rect, {color, color, color, color}, roundness, softness, border_thickness, {border_color, border_color, border_color, border_color})
}

render_rect_gradient :: proc(rect: Rect, colors: [2]Color, roundness: f32, softness: f32, border_thickness: f32, border_colors: [2]Color) {
    render_rect(rect, {colors[1], colors[1], colors[0], colors[0]}, roundness, softness, border_thickness, {border_colors[1], border_colors[1], border_colors[0], border_colors[0]})
}

render_rect_gradient_single_fill_color :: proc(rect: Rect, color: Color, roundness: f32, softness: f32, border_thickness: f32, border_colors: [2]Color) {
    render_rect(rect, {color, color, color, color}, roundness, softness, border_thickness, {border_colors[1], border_colors[1], border_colors[0], border_colors[0]})
}

render_rect_gradient_single_border_color :: proc(rect: Rect, colors: [2]Color, roundness: f32, softness: f32, border_thickness: f32, border_color: Color) {
    render_rect(rect, {colors[1], colors[1], colors[0], colors[0]}, roundness, softness, border_thickness, {border_color, border_color, border_color, border_color})
}

render_rect :: proc(rect: Rect, colors: [4]Color, roundness: f32, softness: f32, border_thickness: f32, border_color: [4]Color) {
    quad := [4]Vertex{
        {
            { -1, -1 },
            { 0, 0 },
            colors[0],
            border_color[0],
            0,
            0,
            rect,
            {roundness, softness, border_thickness, 0.0},
        },
        {
            { 1, -1 },
            { 1, 0 },
            colors[1],
            border_color[1],
            0,
            0,
            rect,
            {roundness, softness, border_thickness, 0.0},
        },
        {
            { 1, 1 },
            { 1, 1 },
            colors[2],
            border_color[2],
            0,
            0, 
            rect,
            {roundness, softness, border_thickness, 0.0},
        },
        {
            { -1, 1 },
            { 0, 1 },
            colors[3],
            border_color[3],
            0,
            0, 
            rect,
            {roundness, softness, border_thickness, 0.0},
        },
    }
    
    renderer_add_quad(&quad)
}

render_texture :: proc(texture: ^Texture, rect: Rect, color: Color, roundness: f32 = 0.0, softness: f32 = 1.0, border_thickness: f32 = 0.0, border_color: Color = {0.0, 0.0, 0.0, 1.0}) {
    if !texture_validate(texture) {
        return
    }

    slot : int = -1
    for i := 0; i < int(gl_renderer.texture_slot); i += 1 {
        if gl_renderer.texture_data[i] == texture.handle {
            slot = i
            break
        }
    }
    
    if slot == -1 {
        gl_renderer.texture_data[gl_renderer.texture_slot] = texture.handle
        slot = int(gl_renderer.texture_slot)
        gl_renderer.texture_slot += 1
    }
    
    quad := [4]Vertex{
        {
            { -1, -1 },
            { 0, 0 },
            color,
            border_color,
            f32(slot),
            1.0,
            rect,
            {roundness, softness, border_thickness, 0.0},
        },
        {
            { 1, -1 },
            { 1, 0 },
            color,
            border_color,
            f32(slot),
            1.0,
            rect,
            {roundness, softness, border_thickness, 0.0},
        },
        {
            { 1, 1 },
            { 1, 1 },
            color,
            border_color,
            f32(slot),
            1.0, 
            rect,
            {roundness, softness, border_thickness, 0.0},
        },
        {
            { -1, 1 },
            { 0, 1 },
            color,
            border_color,
            f32(slot),
            1.0, 
            rect,
            {roundness, softness, border_thickness, 0.0},
        },
    }
    
    renderer_add_quad(&quad)
}

render_text :: proc(font: ^Font, text: string, size: f32, pos: Vec2, color: Vec4) {
    font_atlas := font.container

    if !font_atlas_validate(font_atlas) {
        return
    }
    
    slot : int = -1
    for i := 0; i < int(gl_renderer.texture_slot); i += 1 {
        if gl_renderer.texture_data[i] == font_atlas.texture.handle {
            slot = i
            break
        }
    }
    
    if slot == -1 {
        gl_renderer.texture_data[gl_renderer.texture_slot] = font_atlas.texture.handle
        slot = int(gl_renderer.texture_slot)
        gl_renderer.texture_slot += 1
    }
    
    vertices := [4]Vertex{}
    cpos := pos
    runes := utf8.string_to_runes(text, context.temp_allocator)
    for r := 0; r < len(runes); r += 1 {
        glyph, ok := font.glyphs[runes[r]]
        
        if ok {
            x := math.floor_f32(cpos.x) + glyph.x0
            y := math.floor_f32(cpos.y) + glyph.y0

            eff_dim := Vec2{glyph.x1-glyph.x0, glyph.y1-glyph.y0}

            rect := [4]f32{x, y, x+eff_dim.x, y+eff_dim.y}
            
            quad := [4]Vertex{
                {
                    { -1, -1 },
                    { glyph.u0, glyph.v0 },
                    color,
                    {},
                    f32(slot),
                    2.0,
                    rect,
                    {},
                },
                {
                    { 1, -1 },
                    { glyph.u1, glyph.v0 },
                    color,
                    {},
                    f32(slot),
                    2.0,
                    rect,
                    {},
                },
                {
                    { 1, 1 },
                    { glyph.u1, glyph.v1 },
                    color,
                    {},
                    f32(slot),
                    2.0,
                    rect,
                    {},
                },
                {
                    { -1, 1 },
                    { glyph.u0, glyph.v1 },
                    color,
                    {},
                    f32(slot),
                    2.0,
                    rect,
                    {},
                },
            }
            renderer_add_quad(&quad)

            cpos.x += glyph.advance
        }
    }
}

renderer_begin :: proc() {
    gl_renderer.index_count = 0
    gl_renderer.vertex_data_at = 0
    gl_renderer.texture_slot = 0
}

renderer_end :: proc() {
    if !shader_validate(gl_renderer.shader){
        return
    }

    proj := la.mat4Ortho3d(0, f32(gl_renderer.app.window_size.x), f32(gl_renderer.app.window_size.y), 0, -1.0, 1.0)

    gl.ClearColor(0.1, 0.1, 0.1, 1.0)
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

    gl.BindVertexArray(gl_renderer.vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, gl_renderer.vbo)
    gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(Vertex) * int(gl_renderer.vertex_data_at), cast(rawptr)&gl_renderer.vertex_data[0])
    
	gl.Enable(gl.BLEND)
	gl.Enable(gl.MULTISAMPLE)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)  

    shader_bind(gl_renderer.shader)
    shader_set(gl_renderer.shader, "u_proj", &proj)
    for i : u32 = 0; i < gl_renderer.texture_slot; i += 1 {
        gl.BindTextureUnit(i, gl_renderer.texture_data[i])
    }
    gl.DrawElements(gl.TRIANGLES, gl_renderer.index_count, gl.UNSIGNED_INT, nil)
}

@(private)
renderer_generate_index_data :: proc(quad_count: u32) -> []u32 {
    index_count, offset : u32 = quad_count * 6, 0
    data := make([]u32, index_count)
    for i : u32 = 0; i < index_count; i += 6 {
        data[i + 0] = 0 + offset
        data[i + 1] = 1 + offset
        data[i + 2] = 2 + offset
        data[i + 3] = 2 + offset
        data[i + 4] = 3 + offset
        data[i + 5] = 0 + offset
        offset += 4
    }
    return data
}