package renderer

import "../assets"
import "../platform"

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
    app: ^platform.App,

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
    
    shader: ^assets.Shader,
    font: ^assets.Font,
    white_texture: ^assets.Texture,
}

init :: proc(app: ^platform.App) {
    gl_renderer.app = app

    max_quads : u32 = 65536
    gl_renderer.index_count = 0
    gl_renderer.vertex_data_at = 0
    gl_renderer.vertex_data_cap = max_quads*4
    gl_renderer.vertex_data = make([]Vertex, gl_renderer.vertex_data_cap)
    
    gl_renderer.cached_texture_slot = 0
    gl_renderer.texture_slot = 1
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

    index_data := generate_index_data(max_quads)
    gl.GenBuffers(1, &gl_renderer.ibo)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, gl_renderer.ibo)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, int(size_of(u32) * max_quads * 6), cast(rawptr)&index_data[0], gl.STATIC_DRAW)    
    delete(index_data)
    gl.BindVertexArray(0)

    assets.shader_load(&gl_renderer.shader, app, "shaders/default.glsl")
    assets.font_load(&gl_renderer.font, app, "fonts/OpenSans-Regular.ttf", 80, []assets.Font_Glyph_Range{assets.Font_Glyph_Range_Latin})
    
    gl_renderer.white_texture = assets.texture_create(1, 1, assets.Texture_Format.RGBA)
    gl_renderer.white_texture.data[0] = 0xFF
    gl_renderer.white_texture.data[1] = 0xFF
    gl_renderer.white_texture.data[2] = 0xFF
    gl_renderer.white_texture.data[3] = 0xFF
}

free :: proc() {
    gl.DeleteVertexArrays(1, &gl_renderer.vao)
    gl.DeleteBuffers(1, &gl_renderer.vbo)
    gl.DeleteBuffers(1, &gl_renderer.ibo)

    delete(gl_renderer.vertex_data)
    delete(gl_renderer.texture_data)

    assets.shader_free(&gl_renderer.shader)
    assets.font_free(&gl_renderer.font)
    assets.texture_free(&gl_renderer.white_texture)
}

add_quad :: proc(v: ^[4]Vertex) {
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

draw_text :: proc(text: string, pos: [2]f32, color: [4]f32, size: f32) {
    font := gl_renderer.font
    if !assets.font_validate(gl_renderer.font) {
        return
    }

    slot : int = -1
    for i := 0; i < int(gl_renderer.texture_slot); i += 1 {
        if gl_renderer.texture_data[i] == font.texture.handle {
            slot = i
            break
        }
    }
    
    vertices := [4]Vertex{}

    if slot == -1 {
        gl_renderer.texture_data[gl_renderer.texture_slot] = font.texture.handle
        slot = int(gl_renderer.texture_slot)
        gl_renderer.texture_slot += 1
    }

    cpos := pos
    for r := 0; r < len(text); r += 1 {
        glyph, ok := font.glyphs[rune(text[r])]
        
        if ok {
            if gl_renderer.vertex_data_at + 4 >= gl_renderer.vertex_data_cap {
                log.error("Renderer reached quad limit!")
                return
            }
            
            x := cpos.x + glyph.offset.x
            y := cpos.y - glyph.offset.y

            vertices[0].position = {x, y}
            vertices[1].position = {x+glyph.dim.x, y}
            vertices[2].position = {x+glyph.dim.x, y-glyph.dim.y}
            vertices[3].position = {x, y-glyph.dim.y}
            
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
            
            vertices[0].mode = 1.0
            vertices[1].mode = 1.0
            vertices[2].mode = 1.0
            vertices[3].mode = 1.0

            add_quad(&vertices)

            cpos.x += (glyph.advance - glyph.lsb)
        }
    }
}

begin :: proc() {
    gl_renderer.index_count = 0
    gl_renderer.vertex_data_at = 0
    gl_renderer.texture_slot = 1
}

end :: proc() {
    if !assets.shader_validate(gl_renderer.shader) || !assets.font_validate(gl_renderer.font) || !assets.texture_validate(gl_renderer.white_texture) {
        return
    }

    proj := la.mat4Ortho3d(0, f32(gl_renderer.app.width), 0, f32(gl_renderer.app.height), -1.0, 1.0)

    gl_renderer.texture_data[0] = gl_renderer.white_texture.handle
    
    gl.BindVertexArray(gl_renderer.vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, gl_renderer.vbo)
    gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(Vertex) * int(gl_renderer.vertex_data_at), cast(rawptr)&gl_renderer.vertex_data[0])
    
	gl.Enable(gl.BLEND)
	gl.Enable(gl.MULTISAMPLE)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)  

    gl.ClearColor(0.1, 0.1, 0.1, 1.0)
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

    assets.shader_bind(gl_renderer.shader)
    assets.shader_set(gl_renderer.shader, "u_proj", &proj)
    for i : u32 = 0; i < gl_renderer.texture_slot; i += 1 {
        gl.ActiveTexture(gl.TEXTURE0)
        gl.BindTexture(gl.TEXTURE_2D, gl_renderer.texture_data[i])
    }
    gl.DrawElements(gl.TRIANGLES, gl_renderer.index_count, gl.UNSIGNED_INT, nil)
}

@(private)
generate_index_data :: proc(quad_count: u32) -> []u32 {
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