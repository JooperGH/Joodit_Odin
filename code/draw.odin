package main

import "core:mem"
import "core:slice"
import "core:unicode/utf8"

DRAW_CMD_BUFFER_SIZE :: 64
DRAW_VTX_BUFFER_SIZE :: 4096
DRAW_IDX_BUFFER_SIZE :: 4096*4
DRAW_CLIP_RECT_BUFFER_SIZE :: 64

ALPHA_MASK : u32 : 0xFF000000

Draw_Vtx :: Vertex
Draw_Idx :: u32

Draw_Cmd_Head :: struct {
    clip_rect: Rect,
}

Draw_Cmd :: struct {
    clip_rect: Rect,
    textures: [dynamic]u32,
    vtx_off: u32,
    idx_off: u32,
    idx_count: u32,
}

Draw_Cmd_List :: struct {
    arena: mem.Arena,
    allocator: mem.Allocator,

    cmd_buf: [dynamic]Draw_Cmd,
    vtx_buf: [dynamic]Draw_Vtx,
    idx_buf: [dynamic]Draw_Idx,

    clip_rect_stack: [dynamic]Rect,

    cmd_head: Draw_Cmd_Head,
}

Draw :: struct {
    app: ^App,

    order_idx: i32,
    dcls: [dynamic]^Draw_Cmd_List,
}
dc: Draw

draw_init :: proc(app: ^App) {
    dc.app = app
    dc.dcls = make([dynamic]^Draw_Cmd_List, context.allocator)
    dc.order_idx = 0
}

draw_reset :: proc() {
    for dcl in dc.dcls {
        clear(&dcl.cmd_buf)
        clear(&dcl.vtx_buf)
        clear(&dcl.idx_buf)

        mem.free_all(dcl.allocator)

        draw_new_cmd(dcl, dcl.cmd_head.clip_rect)
        append(&dcl.clip_rect_stack, dcl.cmd_head.clip_rect)
    }
}

draw_new_draw_list :: proc() -> ^Draw_Cmd_List {
    dcl := new(Draw_Cmd_List, context.allocator)
    mem.arena_init(&dcl.arena, make([]byte, mem.Megabyte*2, context.allocator))
    dcl.allocator = mem.arena_allocator(&dcl.arena)

    dcl.cmd_buf = make([dynamic]Draw_Cmd, 0, DRAW_CMD_BUFFER_SIZE, context.allocator)
    dcl.vtx_buf = make([dynamic]Draw_Vtx, 0, DRAW_VTX_BUFFER_SIZE, context.allocator)
    dcl.idx_buf = make([dynamic]Draw_Idx, 0, DRAW_IDX_BUFFER_SIZE, context.allocator)
    dcl.clip_rect_stack = make([dynamic]Rect, 0, DRAW_CLIP_RECT_BUFFER_SIZE, context.allocator)

    dcl.cmd_head.clip_rect = {0, 0, dc.app.window_size.x, dc.app.window_size.y}

    append(&dc.dcls, dcl)
    return dcl
}

@private
draw_get_cmd :: proc(dcl: ^Draw_Cmd_List) -> ^Draw_Cmd {
    cmd := &dcl.cmd_buf[len(dcl.cmd_buf)-1]

    if dcl.clip_rect_stack[len(dcl.clip_rect_stack)-1] != dcl.cmd_head.clip_rect {
        dcl.cmd_head.clip_rect = dcl.clip_rect_stack[len(dcl.clip_rect_stack)-1]
        draw_new_cmd(dcl, dcl.cmd_head.clip_rect)
        cmd = &dcl.cmd_buf[len(dcl.cmd_buf)-1]
    } else if len(cmd.textures) == cap(cmd.textures) {
        draw_new_cmd(dcl, cmd.clip_rect)
        cmd = &dcl.cmd_buf[len(dcl.cmd_buf)-1]
    }

    return cmd
}

@private
draw_new_cmd :: proc(dcl: ^Draw_Cmd_List, clip_rect: Rect) {
    append(&dcl.cmd_buf, Draw_Cmd{
        clip_rect,
        make([dynamic]u32, 0, 32, dcl.allocator),
        u32(len(dcl.vtx_buf)),
        u32(len(dcl.idx_buf)),
        0,
    })
}

@private
draw_reserve :: proc(dcl: ^Draw_Cmd_List, vtx_count, idx_count: u32) -> ([]Draw_Vtx, []Draw_Idx) {
    cmd := draw_get_cmd(dcl)
    cmd.idx_count += u32(idx_count)

    old_vtx_buf_len := u32(len(dcl.vtx_buf))
    resize(&dcl.vtx_buf, int(old_vtx_buf_len+vtx_count))
    
    old_idx_buf_len := u32(len(dcl.idx_buf))
    resize(&dcl.idx_buf, int(old_idx_buf_len+idx_count))

    vtx_buf := dcl.vtx_buf[old_vtx_buf_len:]
    idx_buf := dcl.idx_buf[old_idx_buf_len:]

    return vtx_buf, idx_buf
}

@private
draw_add_idx :: #force_inline proc(idx: []Draw_Idx, dcl_idx_count: int) {
    nis := 4*(dcl_idx_count/6-1)
    idx[0] = u32(nis + 0)
    idx[1] = u32(nis + 1)
    idx[2] = u32(nis + 2)
    idx[3] = u32(nis + 2)
    idx[4] = u32(nis + 3)
    idx[5] = u32(nis + 0)
}

@private
draw_add_vtx :: #force_inline proc(vtx: ^Draw_Vtx, pos_vec: Vec2, tex_coord: Vec2, color, border_color: Color, tex_id: f32, mode: f32, rect: Rect, roundness: f32, border_thickness: f32) {
    vtx.pos_vec = pos_vec
    vtx.tex_coord = tex_coord
    vtx.color = color
    vtx.border_color = border_color
    vtx.tex_id = tex_id
    vtx.mode = mode
    vtx.rect = rect
    vtx.rect_params = {roundness, 1.0, border_thickness, 0.0}
}

@private
draw_add_tex :: proc(dcl: ^Draw_Cmd_List, tex: ^Texture) -> i32 {
    if !texture_validate(tex) do return -1

    cmd := draw_get_cmd(dcl)
    
    index : i32 = -1
    for t, i in cmd.textures {
        if t == tex.handle {
            index = i32(i)
            break
        }
    }

    if index == -1 {
        index = i32(len(cmd.textures))
        assert(index < i32(cap(cmd.textures)))
        append(&cmd.textures, tex.handle)
    }

    return index
}

@private
draw_get_clip_rect_unsafe :: proc(dcl: ^Draw_Cmd_List) -> Rect {
    return dcl.cmd_buf[len(dcl.cmd_buf)-1].clip_rect
}

draw_push_clip_rect :: proc(dcl: ^Draw_Cmd_List, clip_rect: Rect) {
    append(&dcl.clip_rect_stack, clip_rect)
}

draw_pop_clip_rect :: proc(dcl: ^Draw_Cmd_List) {
    assert(len(dcl.clip_rect_stack) > 0)
    pop(&dcl.clip_rect_stack)
}

draw_add_rect :: proc(dcl: ^Draw_Cmd_List, rect: Rect, rounding, border_thickness: f32, color, border_color: [4]Color) {
    if color.a == 0.0 && border_color.a == 0.0 do return    
    if !rect_overlaps(draw_get_clip_rect_unsafe(dcl), rect) do return
    
    vtxs, idxs := draw_reserve(dcl, 4, 6)
    draw_add_idx(idxs, len(dcl.idx_buf))
    draw_add_vtx(&vtxs[0], {-1, -1}, {0, 0}, color[0], border_color[0], 0, 0.0, rect, rounding, border_thickness)
    draw_add_vtx(&vtxs[1], {1, -1}, {1, 0}, color[1], border_color[1], 0, 0.0, rect, rounding, border_thickness)
    draw_add_vtx(&vtxs[2], {1, 1}, {1, 1}, color[2], border_color[2], 0, 0.0, rect, rounding, border_thickness)
    draw_add_vtx(&vtxs[3], {-1, 1}, {0, 1}, color[3], border_color[3], 0, 0.0, rect, rounding, border_thickness)
}

draw_add_text :: proc(dcl: ^Draw_Cmd_List, font: ^Font, text: string, size: f32, pos: Vec2, color: Color) {
    if color.a == 0.0 do return
    if !font_atlas_validate(font.container) do return

    tex_idx := f32(draw_add_tex(dcl, font.container.texture))

    clip_rect := draw_get_clip_rect_unsafe(dcl)

    cpos := pos
    scale := size/font.size
    runes := utf8.string_to_runes(text, dcl.allocator)
    for r, i in runes {
        glyph, ok := font.glyphs[r]

        if ok {
            rect := Rect{
                cpos.x + glyph.x0*scale,
                cpos.y + glyph.y0*scale,
                cpos.x + glyph.x1*scale,
                cpos.y + glyph.y1*scale,
            }

            if !rect_overlaps(clip_rect, rect) do continue

            vtxs, idxs := draw_reserve(dcl, 4, 6)
            draw_add_idx(idxs, len(dcl.idx_buf))
            draw_add_vtx(&vtxs[0], {-1, -1}, {glyph.u0, glyph.v0}, color, {}, tex_idx, 2.0, rect, 0, 0)
            draw_add_vtx(&vtxs[1], {1, -1}, {glyph.u1, glyph.v0}, color, {}, tex_idx, 2.0, rect, 0, 0)
            draw_add_vtx(&vtxs[2], {1, 1}, {glyph.u1, glyph.v1}, color, {}, tex_idx, 2.0, rect, 0, 0)
            draw_add_vtx(&vtxs[3], {-1, 1}, {glyph.u0, glyph.v1}, color, {}, tex_idx, 2.0, rect, 0, 0)
        
            cpos.x += glyph.advance*scale
        }
    }
}
