package main

import "core:slice"
import "core:fmt"
import "core:log"
import "core:mem"
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
    font: ^Font,
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
    font_load(&gl_renderer.font, app, "fonts/OpenSans-Regular.ttf", 40, Font_Glyph_Range_Default, Font_Raster_Type.SDF, 2048, 2048, false)
    
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
    font_free(&gl_renderer.font)
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

render_texture :: proc(texture: ^Texture, rect: Rect, color: Color, roundness: f32 = 0.0, softness: f32 = 2.0, border_thickness: f32 = 0.0, border_color: Color = {0.0, 0.0, 0.0, 1.0}) {
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

render_text :: proc(text: string, size: f32, pos: Vec2, options: Text_Render_Options, color: Vec4) -> Rect {
    font := gl_renderer.font
    if !font_validate(font) {
        return {}
    }

    rect := text_rect(text, size, pos)
    resolved_rect := text_rect_options_resolve(options, rect)
    options_offset := resolved_rect.xy - rect.xy 

    render_mode := font_get_render_mode(gl_renderer.font)

    slot : int = -1
    for i := 0; i < int(gl_renderer.texture_slot); i += 1 {
        if gl_renderer.texture_data[i] == font.texture.handle {
            slot = i
            break
        }
    }
    
    if slot == -1 {
        gl_renderer.texture_data[gl_renderer.texture_slot] = font.texture.handle
        slot = int(gl_renderer.texture_slot)
        gl_renderer.texture_slot += 1
    }
    
    vertices := [4]Vertex{}
    
    cpos := pos + options_offset
    for r := 0; r < len(text); r += 1 {
        rune_a := rune(text[r])
        rune_b := r < len(text)-2 ? rune(text[r+1]) : rune(-1)
        glyph, ok := font.glyphs[rune_a]
        glyph_b, ok_b := font.glyphs[rune_b]
        
        if ok {
            scaling_factor := (size/f32(font.size))
            
            x := cpos.x + glyph.offset.x*scaling_factor
            y := cpos.y - glyph.offset.y*scaling_factor

            eff_dim := glyph.dim * scaling_factor

            rect := [4]f32{x, y, x+eff_dim.x, y-eff_dim.y}

            width : f32 = 0.7
            edge : f32 = 0.025
            quad := [4]Vertex{
                {
                    { -1, -1 },
                    { glyph.uv.x, glyph.uv.w },
                    color,
                    {},
                    f32(slot),
                    render_mode,
                    rect,
                    {width, edge, 0, 0},
                },
                {
                    { 1, -1 },
                    { glyph.uv.z, glyph.uv.w },
                    color,
                    {},
                    f32(slot),
                    render_mode,
                    rect,
                    {width, edge, 0, 0},
                },
                {
                    { 1, 1 },
                    { glyph.uv.z, glyph.uv.y },
                    color,
                    {},
                    f32(slot),
                    render_mode,
                    rect,
                    {width, edge, 0, 0},
                },
                {
                    { -1, 1 },
                    { glyph.uv.x, glyph.uv.y },
                    color,
                    {},
                    f32(slot),
                    render_mode,
                    rect,
                    {width, edge, 0, 0},
                },
            }
            renderer_add_quad(&quad)

            extra : f32 = 0.0
            if ok && ok_b {
                extra = font_glyph_kern(font, &glyph, &glyph_b)
            }

            cpos.x += (glyph.advance + extra) * scaling_factor
        }
    }

    return resolved_rect
}

renderer_begin :: proc() {
    gl_renderer.index_count = 0
    gl_renderer.vertex_data_at = 0
    gl_renderer.texture_slot = 0
}

renderer_end :: proc() {
    if !shader_validate(gl_renderer.shader) || !font_validate(gl_renderer.font) {
        return
    }

    proj := la.mat4Ortho3d(0, f32(gl_renderer.app.width), 0, f32(gl_renderer.app.height), -1.0, 1.0)

    gl.BindVertexArray(gl_renderer.vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, gl_renderer.vbo)
    gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(Vertex) * int(gl_renderer.vertex_data_at), cast(rawptr)&gl_renderer.vertex_data[0])
    
	gl.Enable(gl.BLEND)
	gl.Enable(gl.MULTISAMPLE)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)  

    gl.ClearColor(0.1, 0.1, 0.1, 1.0)
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

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