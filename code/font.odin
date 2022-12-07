package main

import "core:log"
import "core:fmt"
import "core:os"
import "core:thread"
import "core:sort"
import "core:slice"
import "core:mem"
import "core:strings"
import "core:math"

import stbtt "vendor:stb/truetype"
import stbrp "vendor:stb/rect_pack"

Font_Info :: ^stbtt.fontinfo

Font_Load_Task_Data :: struct {
    font: ^^Font,
    paths: []string,
    ranges: []Font_Glyph_Range,
    sizes: []i32,
}

Font :: struct {
    infos: []Font_Info,
    datas: [][]byte,

    texture: ^Texture,
    glyphs: map[rune]Font_Glyph,
    scales: []f32,
    sizes: []i32,
    baselines: []f32,
    line_advances: []f32,
    paddings: []f32,

    load_state: Load_State,
} 

Font_Glyph :: struct {
    font_index: i32,
    codepoint: rune,
    advance: f32,
    x0, y0, x1, y1: f32,
    u0, v0, u1, v1: f32,
}

Font_Glyph_Range :: []rune
font_glyph_range_default :: proc(allocator: mem.Allocator = context.allocator) -> Font_Glyph_Range {
    result := make([]rune, 5, allocator)
    result[0] = 0x0020
    result[1] = 0x00FF
    result[2] = 0x2000
    result[3] = 0x206F
    return result
}

font_load :: proc(font: ^^Font, app: ^App, paths: []string, sizes: []i32, ranges: []Font_Glyph_Range, threaded: bool = true){
    if !check_load_state(cast(rawptr)font^, Font, proc(data: rawptr) {
        font := cast(^Font)data
        font_free(&font)
    }) {
        return
    }

    log.debug("Font load request at ", app_time())

    assert(len(ranges) != 0)
    assert(len(ranges) == len(sizes) && len(ranges) == len(paths))
    
    font^ = new(Font)
    font^.load_state = .Queued

    data := new(Font_Load_Task_Data, context.allocator)
    data.font = font

    data.sizes = make([]i32, len(sizes))
    i := 0
    for size in sizes {
        data.sizes[i] = size
        i += 1
    }
        
    data.paths = make([]string, len(paths))
    i = 0
    for path in paths {
        data.paths[i] = strings.clone(path, context.allocator)
        i += 1
    }

    data.ranges = make([]Font_Glyph_Range, len(ranges))
    i = 0
    for range in ranges {
        data.ranges[i] = slice.clone(range, context.allocator)
        i += 1
    }

    if threaded {
        app_push_task(app, font_load_task, cast(rawptr)data)
    } else {
        ttask := thread.Task{}
        ttask.allocator = context.allocator
        ttask.data = cast(rawptr)data
        ttask.user_index = context.user_index
        font_load_task(ttask)
    }
}

font_glyph_kern :: proc(font: ^Font, a: ^Font_Glyph, b: ^Font_Glyph) -> f32 {
    //kern := stbtt.GetGlyphKernAdvance(font.data, a.index, b.index)

    return 0.0 //f32(kern) * font.scale 
}
/*
@(private)
font_stb_sdf_raster :: proc(font: ^Font, rpc: ^rp.Context) {
    font.padding = 16.0
    pixel_dist_scale : f32 = f32(127)/f32(font.padding)

    w, h: i32
    g := 0

    for range in font.ranges {
        for r := range[0]; r <= range[1]; r += 1 {
            bg := new(Font_Builder_Glyph, rpc.allocator)
            bg.codepoint = cast(rune)r
            bitmap := stbtt.GetCodepointSDF(font.data, font.scale, r, i32(font.padding), 180, pixel_dist_scale, 
                                                 &w, &h, 
                                                 &bg.offset.x, &bg.offset.y)
            if bitmap != nil {
                rp.push(rpc, w, h, cast(rawptr)bg, bitmap[:(w*h)])
            }
            g += 1
        }
    }
}

/*
@(private)
font_pack_rects :: proc(font: ^Font, glyphs: []Font_Builder_Glyph) -> b32 {    
    sort.quick_sort_proc(glyphs, proc(a: Font_Builder_Glyph, b: Font_Builder_Glyph) -> int {
        return a.box.w < b.box.w ? 0 : 1
    })

    x, y, mh : i32 = 0, 0, 0
    for i := 0; i < len(glyphs); i += 1 {
        box := &glyphs[i].box

        if x + box.z > font.texture.w {
            y += mh
            x = 0
            mh = 0
        }

        if y + box.w > font.texture.h {
            return false
        }

        box.x = x
        box.y = y

        x += box.z

        if box.w > mh {
            mh = box.w
        }
    }

    return true
}
*/
@(private)
font_build_atlas :: proc(font: ^Font, rpc: ^rp.Context) {
    for r in rpc.rects {
        built_glyph := cast(^Font_Builder_Glyph)r.user_data
        lsb, adv: i32
        stbtt.GetCodepointHMetrics(font.data, built_glyph.codepoint, &adv, &lsb)

        glyph := Font_Glyph{
            stbtt.FindGlyphIndex(font.data, built_glyph.codepoint),
            f32(adv)*font.scale, 
            f32(lsb)*font.scale,
            [2]f32{f32(built_glyph.offset.x) + font.padding, f32(built_glyph.offset.y)},
            [2]f32{f32(r.w) - font.padding, f32(r.h) - font.padding},
            [4]f32{
                (f32(r.x) + font.padding/2)/f32(font.texture.w),
                (f32(r.y+r.h)-font.padding/2)/f32(font.texture.h),
                (f32(r.x+r.w)-font.padding/2)/f32(font.texture.w),
                (f32(r.y) + font.padding/2)/f32(font.texture.h),
            },
        }

        font.glyphs[built_glyph.codepoint] = glyph

        if r.w != 0 && r.h != 0 {
            for y : i32 = 0; y < r.h; y += 1 {
                for x : i32 = 0; x < r.w; x += 1 {
                    font.texture.data[(r.x + x) + font.texture.w * (r.y + y)] = r.data[x + r.w * y]
                }   
            }    
        }
    }
}

*/

Font_Build_Src_Data :: struct {
    pack_range: stbtt.pack_range,
    rects: []stbrp.Rect,
    packed_chars: []stbtt.packedchar,
    glyph_highest, glyph_lowest: rune,
    glyph_count: i32,
    glyph_set: []u8,
    glyph_list: []rune,
}

Font_Build_Dst_Data :: struct {
    glyph_highest, glyph_lowest: rune,
    glyph_count: i32,
    glyph_set: []u8,
    glyph_list: []rune,
}

@(private)
font_load_task :: proc(task: thread.Task) {
    task_data := cast(^Font_Load_Task_Data)task.data
    
    if len(task_data.paths) > 0  {
        font := task_data.font^
        font.sizes = task_data.sizes
        font.infos =  make([]Font_Info, len(task_data.paths), context.allocator)
        font.datas =  make([][]byte, len(task_data.paths), context.allocator)
        font.scales =  make([]f32, len(task_data.paths), context.allocator)
        font.baselines =  make([]f32, len(task_data.paths), context.allocator)
        font.line_advances =  make([]f32, len(task_data.paths), context.allocator)
        font.paddings =  make([]f32, len(task_data.paths), context.allocator)

        // 1) Initialize font info and check for low-max glyph codepoint 
        ranges := task_data.ranges
        dst_data := Font_Build_Dst_Data{}
        src_data := make([]Font_Build_Src_Data, len(font.infos), context.temp_allocator)
        for path, i in task_data.paths {
            src_data[i].glyph_highest = ranges[i][0]
            src_data[i].glyph_lowest = ranges[i][0]
            src_data[i].glyph_count = 0

            data, ok := os.read_entire_file_from_filename(path, context.allocator)
            if !ok {
                return
            }

            font.datas[i] = data
            font.infos[i] = new(stbtt.fontinfo)
            if !stbtt.InitFont(font.infos[i], &data[0], 0) {
                log.error("Failed to load font ", path, ".")
                return
            }

            range := ranges[i]
            for ri := 0; ri < len(range)-2; ri += 2 { 
                for r in range[ri]..=range[ri+1] {
                    src_data[i].glyph_highest = max(src_data[i].glyph_highest, r)
                    src_data[i].glyph_lowest = min(src_data[i].glyph_lowest, r)
                }
            }

            dst_data.glyph_highest = max(dst_data.glyph_highest, src_data[i].glyph_highest)
            dst_data.glyph_lowest = min(dst_data.glyph_lowest, src_data[i].glyph_lowest)

            font.scales[i] = stbtt.ScaleForPixelHeight(font.infos[i], f32(font.sizes[i]))

            u_ascent, u_descent, u_line_gap: i32 
            stbtt.GetFontVMetrics(font.infos[i], &u_ascent, &u_descent, &u_line_gap)
            ascent := math.floor_f32(f32(u_ascent) * font.scales[i] + ((f32(u_ascent) > 0.0) ? +1.0 : -1.0));
            descent := math.floor_f32(f32(u_descent) * font.scales[i] + ((f32(u_descent) > 0.0) ? +1.0 : -1.0));
            line_gap := math.floor_f32(f32(u_line_gap) * font.scales[i] + ((f32(u_line_gap) > 0.0) ? +1.0 : -1.0));
            font.baselines[i] = ascent
            font.line_advances[i] = ascent - descent + line_gap
        }
        
        // 2) Find every glyph and check if it exists in the font
        total_glyph_count := 0
        dst_data.glyph_set = make([]u8, dst_data.glyph_highest+1, context.temp_allocator)
        for info, i in font.infos {
            src_data[i].glyph_set = make([]u8, src_data[i].glyph_highest+1, context.temp_allocator)
            for ri := 0; ri < len(ranges[i])-2; ri += 2 { 
                for r := ranges[i][ri]; r <= ranges[i][ri+1]; r += 1 {
                    if dst_data.glyph_set[r] != 0 do continue
                    if stbtt.FindGlyphIndex(info, r) == 0 do continue

                    src_data[i].glyph_set[r] = 1
                    dst_data.glyph_set[r] = 1
                    src_data[i].glyph_count += 1
                    dst_data.glyph_count += 1
                    total_glyph_count += 1
                }
            }
        }

        // 3) Build codepoint lists
        for info, i in font.infos {
            src_data[i].glyph_list = make([]rune, src_data[i].glyph_count, context.temp_allocator)
            k := 0
            for j : rune = 0; j < src_data[i].glyph_highest+1; j += 1 {
                if src_data[i].glyph_set[j] != 0 { 
                    src_data[i].glyph_list[k] = j
                    k += 1
                }
            }
            assert(i32(len(src_data[i].glyph_list)) == src_data[i].glyph_count)
        }

        // 4) Gather glyph sizes!
        packed_chars := make([]stbtt.packedchar, total_glyph_count, context.temp_allocator) 
        rects := make([]stbrp.Rect, total_glyph_count, context.temp_allocator)
    
        oversample_h : i32 = 4
        oversample_v : i32 = 4
        padding : i32 = 10
        area : i32 = 0
        rects_out : i32 = 0
        packed_chars_out : i32 = 0
        for src, i in &src_data {
            if src.glyph_count == 0 {
                continue
            }
            src.rects = rects[rects_out:(rects_out+src.glyph_count)]
            src.packed_chars = packed_chars[packed_chars_out:(packed_chars_out+src.glyph_count)]
            rects_out += src.glyph_count
            packed_chars_out += src.glyph_count

            src.pack_range.font_size = f32(font.sizes[i])
            src.pack_range.first_unicode_codepoint_in_range = 0
            src.pack_range.array_of_unicode_codepoints = &src.glyph_list[0]
            src.pack_range.num_chars = i32(len(src.glyph_list))
            src.pack_range.chardata_for_range = raw_data(src.packed_chars)

            for gi := 0; gi < len(src.glyph_list); gi += 1 {
                x0, y0, x1, y1: i32
                glyph_index_in_font := stbtt.FindGlyphIndex(font.infos[i], src.glyph_list[gi]);
                assert(glyph_index_in_font != 0)
                stbtt.GetGlyphBitmapBoxSubpixel(font.infos[i], glyph_index_in_font, font.scales[i] * f32(oversample_h), font.scales[i] * f32(oversample_v), 0, 0, &x0, &y0, &x1, &y1)
                src.rects[gi].w = stbrp.Coord(x1 - x0 + padding + oversample_h - 1)
                src.rects[gi].h = stbrp.Coord(y1 - y0 + padding + oversample_v - 1)
                area += i32(src.rects[gi].w * src.rects[gi].h)
            }
        }
        
        area_sqrt := math.sqrt_f32(f32(area))
        tex_width := u32((area_sqrt >= 4096 * 0.7) ? 4096 : (area_sqrt >= 2048 * 0.7) ? 2048 : (area_sqrt >= 1024 * 0.7) ? 1024 : 512)
        tex_height : u32 = tex_width

        spc := stbtt.pack_context{}
        stbtt.PackBegin(&spc, nil, i32(tex_width), 1024*32, 0, padding, nil)
        
        font.texture = texture_create(i32(tex_width), i32(next_pow_2(tex_height)), Texture_Format.Alpha)
        spc.pixels = &font.texture.data[0]
        spc.height = font.texture.h

        for src, i in &src_data {
            stbtt.PackSetOversampling(&spc, u32(oversample_h), u32(oversample_v))
            stbtt.PackFontRanges(&spc, raw_data(font.datas[i]), 0, &src.pack_range, 1)
        }

        stbtt.PackEnd(&spc)

        glyph := Font_Glyph{}
        font.glyphs = make(map[rune]Font_Glyph, total_glyph_count, context.allocator)
        for src, i in &src_data {
            for gi : i32 = 0; gi < i32(src.glyph_count); gi += 1 {
                codepoint := src.glyph_list[gi]
                pc := &src.packed_chars[gi]
                q: stbtt.aligned_quad
                _x, _y: f32
                stbtt.GetPackedQuad(raw_data(src.packed_chars), font.texture.w, font.texture.h, gi, &_x, &_y, &q, false)
                
                glyph.font_index = i32(i)
                glyph.codepoint = codepoint
                glyph.x0 = q.x0
                glyph.y0 = q.y0
                glyph.x1 = q.x1
                glyph.y1 = q.y1
                glyph.u0 = q.s0
                glyph.v0 = q.t0
                glyph.u1 = q.s1
                glyph.v1 = q.t1
                glyph.advance = pc.xadvance
                font.glyphs[codepoint] = glyph
            }
        }

        font.load_state = .Loaded_And_Not_Uploaded
		log.debug("Font load request succeeded at ", app_time())
    } else {
        task_data.font^.load_state = .Invalid
    }

    free(task_data, context.allocator)
}

font_validate :: proc(font: ^Font) -> b32 {
    if font == nil {
        return false
    }

    if font.load_state == .Invalid do return false

    if font.load_state == .Unloaded || font.load_state == .Queued {
        return false
    }

    if texture_validate(font.texture) && font.load_state == .Loaded_And_Not_Uploaded {
        font.load_state = .Loaded_And_Uploaded
        return true
    }

    if texture_validate(font.texture) && font.load_state == .Loaded_And_Uploaded {
        return true
    }

    return false
}

font_free :: proc(font: ^^Font) {
    if font^ != nil {
        for data in font^.datas {
            delete(data)
        }
        delete(font^.datas)

        for info in font^.infos {
            free(info)
        }
        delete(font^.infos)

        delete(font^.glyphs)
        delete(font^.sizes)
        delete(font^.scales)
        delete(font^.paddings)
        delete(font^.line_advances)
        delete(font^.baselines)

        texture_free(&font^.texture)

        free(font^)
        font^ = nil
    }
}

font_add_glyph :: proc(codepoint: rune, x0, y0, x1, y1, u0, v0, u1, v1, adv: f32) {

}

font_fallback_scaling_factor :: proc(font: ^Font, size: f32) -> f32 {
    if !font_validate(font) {
        return 0.0
    }

    return size / f32(font.sizes[0])
}

font_scaling_factor :: proc(font: ^Font, glyph: ^Font_Glyph, size: f32) -> f32 {
    if !font_validate(font) {
        return 0.0
    }

    return size / f32(font.sizes[glyph.font_index])
}

font_line_advance :: proc(font: ^Font, glyph: ^Font_Glyph, size: f32) -> f32 {
    if !font_validate(font) {
        return 0.0
    }

    scaling_factor := font_scaling_factor(font, glyph, size)
    return (font.line_advances[glyph.font_index]) * scaling_factor
}

font_glyph_metrics :: proc(font: ^Font, glyph: ^Font_Glyph, size: f32) -> (sf: f32, bl: f32, la: f32, adv: f32) {
    if !font_validate(font) {
        return 0.0, 0.0, 0.0, 0.0
    }

    sf = font_scaling_factor(font, glyph, size)
    bl = font.baselines[glyph.font_index] * sf
    la = font.line_advances[glyph.font_index] * sf
    adv = glyph.advance * sf
    return
}
