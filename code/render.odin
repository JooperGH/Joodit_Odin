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
    position: [2]f32,
    tex_coord: [2]f32,
    color: [4]f32,
    tex_id: f32,
    mode: f32,
}

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
    gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, size_of(Vertex), offset_of(Vertex, position))
    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, size_of(Vertex), offset_of(Vertex, tex_coord))
    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(2, 4, gl.FLOAT, gl.FALSE, size_of(Vertex), offset_of(Vertex, color))
    gl.EnableVertexAttribArray(2)
    gl.VertexAttribPointer(3, 1, gl.FLOAT, gl.FALSE, size_of(Vertex), offset_of(Vertex, tex_id))
    gl.EnableVertexAttribArray(3)
    gl.VertexAttribPointer(4, 1, gl.FLOAT, gl.FALSE, size_of(Vertex), offset_of(Vertex, mode))
    gl.EnableVertexAttribArray(4)

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

renderer_draw :: proc{renderer_draw_rect, renderer_draw_text, renderer_draw_texture}

renderer_draw_rect :: proc(rect: [4]f32, color: [4]f32) {
    quad := [4]Vertex{
        {
            rect.xy,
            { 0, 0 },
            color,
            0,
            0,
        },
        {
            rect.zy,
            { 1, 0 },
            color,
            0,
            0,
        },
        {
            rect.zw,
            { 1, 1 },
            color,
            0,
            0, 
        },
        {
            rect.xw,
            { 0, 1 },
            color,
            0,
            0, 
        },
    }
    
    renderer_add_quad(&quad)
}

renderer_draw_texture :: proc(texture: ^Texture, rect: [4]f32, color: [4]f32) {
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
            rect.xy,
            { 0, 0 },
            color,
            f32(slot),
            1.0,
        },
        {
            rect.zy,
            { 1, 0 },
            color,
            f32(slot),
            1.0,
        },
        {
            rect.zw,
            { 1, 1 },
            color,
            f32(slot),
            1.0, 
        },
        {
            rect.xw,
            { 0, 1 },
            color,
            f32(slot),
            1.0, 
        },
    }
    
    renderer_add_quad(&quad)
}

renderer_draw_text :: proc(text: string, pos: [2]f32, color: [4]f32, size: f32) {
    font := gl_renderer.font
    if !font_validate(gl_renderer.font) {
        return
    }

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
    
    cpos := pos
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

            vertices[0].position = {x, y}
            vertices[1].position = {x+eff_dim.x, y}
            vertices[2].position = {x+eff_dim.x, y-eff_dim.y}
            vertices[3].position = {x, y-eff_dim.y}
            
            vertices[0].tex_coord = {glyph.uv.x, glyph.uv.w}
            vertices[1].tex_coord = {glyph.uv.z, glyph.uv.w}
            vertices[2].tex_coord = {glyph.uv.z, glyph.uv.y}
            vertices[3].tex_coord = {glyph.uv.x, glyph.uv.y}

            vertices[0].color = {color.r, color.g, color.b, color.a}
            vertices[1].color = {color.r, color.g, color.b, color.a}
            vertices[2].color = {color.r, color.g, color.b, color.a}
            vertices[3].color = {color.r, color.g, color.b, color.a}

            vertices[0].tex_id = f32(slot)
            vertices[1].tex_id = f32(slot)
            vertices[2].tex_id = f32(slot)
            vertices[3].tex_id = f32(slot)
            
            vertices[0].mode = render_mode
            vertices[1].mode = render_mode
            vertices[2].mode = render_mode
            vertices[3].mode = render_mode

            renderer_add_quad(&vertices)

            extra : f32 = 0.0
            if ok && ok_b {
                extra = font_glyph_kern(font, &glyph, &glyph_b)
            }

            cpos.x += (glyph.advance + extra) * scaling_factor
        }
    }
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