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
import "core:unicode/utf8"

import stbtt "vendor:stb/truetype"

Font_Info :: stbtt.fontinfo

Font :: struct {
    glyphs: map[rune]Font_Glyph,
    size: f32,
    baseline: f32,
    ascent, descent: f32,
    line_advance: f32,
    
    container: ^Font_Atlas,
    configs: [dynamic]^Font_Config,
}

Font_Config :: struct {
    data: []byte,
    size: f32,
    oversample_x: i32,
    oversample_y: i32,
    padding: i32,
    glyph_spacing: Vec2,
    glyph_offset: Vec2,
    glyph_ranges: Font_Glyph_Range,

    dst_font: ^Font,
}

Font_Atlas :: struct {
    texture: ^Texture,
    padding: i32,
    
    fonts: [dynamic]^Font,
    configs: [dynamic]^Font_Config,

    load_state: Load_State,
}

font_atlas_create :: proc() -> ^Font_Atlas {
    result := new(Font_Atlas, context.allocator)
    result.load_state = .Unloaded
    result.fonts = make([dynamic]^Font, context.allocator)
    result.configs = make([dynamic]^Font_Config, context.allocator)
    result.padding = 1
    return result
}

Font_Glyph :: struct {
    font_index: i32,
    codepoint: rune,
    advance: f32,
    x0, y0, x1, y1: f32,
    u0, v0, u1, v1: f32,
}

Font_Build_Src_Data :: struct {
    info: Font_Info,
    pack_range: stbtt.pack_range,
    packed_chars: []stbtt.packedchar,
    ranges: Font_Glyph_Range,
    dst_idx: i32,
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
    src_count: i32,
}

Font_Glyph_Range :: []rune

font_atlas_add_font_from_ttf :: proc(font_atlas: ^Font_Atlas, app: ^App, path: string, size: f32, merge_mode: b32 = false) -> ^Font {
    log.debug("Font load request at ", app_time())

    font, cfg, ok := font_config_default(font_atlas, path, size, merge_mode)
    if !ok {
        return nil
    }

    font_atlas.load_state = .Loaded_And_Not_Uploaded

    return font
}


// This code takes extremely heavy inspiration from imgui
font_atlas_build :: proc(font_atlas: ^Font_Atlas) {
    fonts := &font_atlas.fonts
    configs := &font_atlas.configs

    // 1) Initialize font info and check for low-max glyph codepoint 
    dst_data := make([]Font_Build_Dst_Data, len(fonts), context.temp_allocator)
    src_data := make([]Font_Build_Src_Data, len(configs), context.temp_allocator)
    for src, i in &src_data {
        cfg := font_atlas.configs[i]
        
        src.dst_idx = -1
        for oi := 0; oi < len(font_atlas.fonts) && src.dst_idx == -1; oi += 1 {
            if cfg.dst_font == font_atlas.fonts[oi] do src.dst_idx = i32(oi)
        }

        if src.dst_idx == -1 {
            log.error("Could not find destination font in font atlas.")
            return
        } 

        if !stbtt.InitFont(&src.info, raw_data(cfg.data), 0) {
            log.error("Failed to initialize font while building atlas.")
            return
        }

        src.glyph_highest = cfg.glyph_ranges[0]
        src.glyph_lowest = cfg.glyph_ranges[0]
        src.glyph_count = 0
        src.ranges = cfg.glyph_ranges
        for ri := 0; ri < len(src.ranges)-2; ri += 2 { 
            for r in src.ranges[ri]..=src.ranges[ri+1] {
                src.glyph_highest = max(src.glyph_highest, r)
                src.glyph_lowest = min(src.glyph_lowest, r)
            }
        }

        dst := &dst_data[src.dst_idx]
        dst.src_count += 1
        dst.glyph_highest = max(dst.glyph_highest, src.glyph_highest)
        dst.glyph_lowest = min(dst.glyph_lowest, src.glyph_lowest)
    }
    
    // 2) Find every glyph and check if it exists in the font
    total_glyph_count := 0
    for src in &src_data {
        dst := &dst_data[src.dst_idx]
        src.glyph_set = make([]u8, src.glyph_highest+1, context.temp_allocator)
        if dst.glyph_set == nil do dst.glyph_set = make([]u8, dst.glyph_highest+1, context.temp_allocator)

        for ri := 0; ri < len(src.ranges)-2; ri += 2 { 
            for r in src.ranges[ri]..=src.ranges[ri+1] {
                if dst.glyph_set[r] != 0 do continue
                if stbtt.FindGlyphIndex(&src.info, r) == 0 do continue

                src.glyph_set[r] = 1
                dst.glyph_set[r] = 1
                src.glyph_count += 1
                dst.glyph_count += 1
                total_glyph_count += 1
            }
        }
    }

    // 3) Build codepoint lists
    for src in &src_data {
        src.glyph_list = make([]rune, src.glyph_count, context.temp_allocator)
        k := 0
        for j in 0..=src.glyph_highest {
            if src.glyph_set[j] != 0 { 
                src.glyph_list[k] = j
                k += 1
            }
        }
        assert(i32(len(src.glyph_list)) == src.glyph_count)
    }

    // 4) Gather glyph sizes!
    packed_chars := make([]stbtt.packedchar, total_glyph_count, context.temp_allocator) 
    
    area : i32 = 0
    rects_out : i32 = 0
    packed_chars_out : i32 = 0
    for src, i in &src_data {
        if src.glyph_count == 0 {
            continue
        }
        src.packed_chars = packed_chars[packed_chars_out:(packed_chars_out+src.glyph_count)]
        packed_chars_out += src.glyph_count

        cfg := font_atlas.configs[i]
        src.pack_range.font_size = cfg.size
        src.pack_range.first_unicode_codepoint_in_range = 0
        src.pack_range.array_of_unicode_codepoints = &src.glyph_list[0]
        src.pack_range.num_chars = i32(len(src.glyph_list))
        src.pack_range.chardata_for_range = raw_data(src.packed_chars)

        scale := cfg.size > 0 ? stbtt.ScaleForPixelHeight(&src.info, cfg.size) : stbtt.ScaleForMappingEmToPixels(&src.info, -cfg.size)
        padding := font_atlas.padding
        for gi := 0; gi < len(src.glyph_list); gi += 1 {
            x0, y0, x1, y1: i32
            glyph_index_in_font := stbtt.FindGlyphIndex(&src.info, src.glyph_list[gi]);
            assert(glyph_index_in_font != 0)
            stbtt.GetGlyphBitmapBoxSubpixel(&src.info, glyph_index_in_font, scale * f32(cfg.oversample_x), scale * f32(cfg.oversample_y), 0, 0, &x0, &y0, &x1, &y1)
            w := x1 - x0 + padding + cfg.oversample_x - 1
            h := y1 - y0 + padding + cfg.oversample_y - 1
            area += i32(w * h)
        }
    }
    
    area_sqrt := math.sqrt_f32(f32(area))
    tex_width := u32((area_sqrt >= 4096 * 0.7) ? 4096 : (area_sqrt >= 2048 * 0.7) ? 2048 : (area_sqrt >= 1024 * 0.7) ? 1024 : 512)
    tex_height : u32 = tex_width
    font_atlas.texture = texture_create(i32(tex_width), i32(next_pow_2(tex_height)), Texture_Format.Alpha)

    spc := stbtt.pack_context{}
    stbtt.PackBegin(&spc, &font_atlas.texture.data[0], i32(tex_width), i32(tex_height), 0, font_atlas.padding, nil)
    
    for src, i in &src_data {
        cfg := font_atlas.configs[i]
        stbtt.PackSetOversampling(&spc, u32(cfg.oversample_x), u32(cfg.oversample_y))
        stbtt.PackFontRanges(&spc, raw_data(cfg.data), 0, &src.pack_range, 1)
    }

    stbtt.PackEnd(&spc)

    glyph := Font_Glyph{}
    for src, i in &src_data {
        if src.glyph_count == 0 {
            continue
        }

        cfg := font_atlas.configs[i]
        font := cfg.dst_font

        font_scale := stbtt.ScaleForPixelHeight(&src.info, cfg.size)
        uns_ascent, uns_descent, uns_line_gap: i32
        stbtt.GetFontVMetrics(&src.info, &uns_ascent, &uns_descent, &uns_line_gap)

        ascent := math.floor_f32(f32(uns_ascent) * font_scale + (f32(uns_ascent) > 0.0 ? 1.0 : -1.0))
        descent := math.floor_f32(f32(uns_descent) * font_scale + (f32(uns_descent) > 0.0 ? 1.0 : -1.0))
        line_gap := math.floor_f32(f32(uns_line_gap) * font_scale + (f32(uns_line_gap) > 0.0 ? 1.0 : -1.0))
        
        font.size = cfg.size
        font.ascent = ascent
        font.descent = descent
        font.baseline = ascent
        font.line_advance = ascent - descent + line_gap

        font_offset_x := cfg.glyph_offset.x
        font_offset_y := cfg.glyph_offset.y// + math.round(font.baseline)
        
        font.glyphs = make(map[rune]Font_Glyph, total_glyph_count, context.allocator)
        for gi : i32 = 0; gi < i32(src.glyph_count); gi += 1 {
            codepoint := src.glyph_list[gi]
            pc := &src.packed_chars[gi]
            q: stbtt.aligned_quad
            _x, _y: f32
            stbtt.GetPackedQuad(raw_data(src.packed_chars), font_atlas.texture.w, font_atlas.texture.h, gi, &_x, &_y, &q, false)
            
            glyph.font_index = i32(i)
            glyph.codepoint = codepoint
            glyph.x0 = q.x0 + font_offset_x
            glyph.y0 = q.y0 + font_offset_y
            glyph.x1 = q.x1 + font_offset_x
            glyph.y1 = q.y1 + font_offset_y
            glyph.u0 = q.s0
            glyph.v0 = q.t0
            glyph.u1 = q.s1
            glyph.v1 = q.t1
            glyph.advance = pc.xadvance
            font.glyphs[codepoint] = glyph
        }
    }

    font_atlas.load_state = .Loaded_And_Not_Uploaded
    log.debug("Font atlas built at", app_time())
}

font_atlas_validate :: proc(font_atlas: ^Font_Atlas) -> b32 {
    if font_atlas == nil {
        return false
    }

    assert(font_atlas.load_state == .Loaded_And_Not_Uploaded || font_atlas.load_state == .Loaded_And_Uploaded)

    if font_atlas.load_state == .Loaded_And_Not_Uploaded {

    }

    if font_atlas.load_state == .Invalid do return false


    if texture_validate(font_atlas.texture) && font_atlas.load_state == .Loaded_And_Not_Uploaded {
        font_atlas.load_state = .Loaded_And_Uploaded
        return true
    }

    if texture_validate(font_atlas.texture) && font_atlas.load_state == .Loaded_And_Uploaded {
        return true
    }

    return false
}

font_atlas_free :: proc(font_atlas: ^^Font_Atlas) {
    if font_atlas^ != nil {
        fa := font_atlas^
        fa.load_state = .Invalid
        texture_free(&fa.texture)

        for cfg in fa.configs {
            delete(cfg.data)
            free(cfg)
        }

        for font in fa.fonts {
            delete(font.configs)
            delete(font.glyphs)
            free(font)
        }
        font_atlas^ = nil    
    }
}

@private
font_config_default :: proc(font_atlas: ^Font_Atlas, path: string, size: f32, merge_mode: b32 = false) -> (^Font, ^Font_Config, b32) {
    config := new(Font_Config, context.allocator)
    
    font : ^Font = nil
    if !merge_mode {
        font = new(Font, context.allocator)
        font.container = font_atlas
        font.configs = make([dynamic]^Font_Config, context.allocator)
    } else {
        assert(len(font_atlas.fonts) > 0)
        font = slice.last(font_atlas.fonts[:])
    }
    config.dst_font = font
    append(&font.configs, config)

    data, ok := os.read_entire_file_from_filename(path, context.allocator)
    if !ok {
        return font, config, false
    }

    config.data = data
    config.size = size
    config.oversample_x = 4
    config.oversample_y = 4
    config.padding = 8
    config.glyph_ranges = font_glyph_range_default(context.allocator)

    font_atlas_push_font_and_config(font_atlas, font, config)
    return font, config, true
}

@private
font_glyph_range_default :: proc(allocator: mem.Allocator = context.allocator) -> Font_Glyph_Range {
    result := make([]rune, 5, allocator)
    result[0] = 0x0020
    result[1] = 0x00FF
    result[2] = 0x2000
    result[3] = 0x206F
    return result
}

@private
font_atlas_push_font_and_config :: proc(font_atlas: ^Font_Atlas, font: ^Font, cfg: ^Font_Config, merge_mode: b32 = false) {
    append(&font_atlas.fonts, font)
    if !merge_mode do append(&font_atlas.configs, cfg)
}

calc_text_rect :: proc(font: ^Font, str: string, size: f32, pos: Vec2) -> Rect {
    font_atlas := font.container
    if !font_atlas_validate(font_atlas) {
        return {}
    }

    result := Rect{pos.x, pos.y, pos.x, pos.y}

    cpos := Vec2{math.floor(pos.x), math.floor(pos.y)}
    scale := size/font.size

    runes := utf8.string_to_runes(str, context.temp_allocator)
    for r in runes {
        glyph, ok := font.glyphs[r]

        if ok {
            x := cpos.x + glyph.x0
            y := cpos.y + glyph.y0

            eff_dim := Vec2{glyph.x1-glyph.x0, glyph.y1-glyph.y0}

            result = rect_union(result, {x, y, x+eff_dim.x, y+eff_dim.y})
        
            cpos.x += glyph.advance
        }
    }

    return result
}
calc_text_size :: #force_inline proc(font: ^Font, str: string, size: f32) -> Vec2 {
    return rect_dim(calc_text_rect(font, str, size, {0, 0}))
}