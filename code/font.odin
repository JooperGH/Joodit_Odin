package main

import "core:log"
import "core:fmt"
import "core:os"
import "core:thread"
import "core:sort"
import "core:slice"

import stbtt "vendor:stb/truetype"

Font_Data :: ^stbtt.fontinfo

Font_Load_Task_Data :: struct {
    font: ^^Font,
    path: string,
    size: i32,
    atlas_width: i32,
    atlas_height: i32,
    ranges: []Font_Glyph_Range,
    raster_type: Font_Raster_Type,
}

Font_Raster_Type :: enum {
    SDF,
    Bitmap,
}

Font :: struct {
    data: Font_Data,

    raster_type: Font_Raster_Type,

    scale: f32,
    size: i32,
    texture: ^Texture,

    ranges: []Font_Glyph_Range,
    glyphs: map[rune]Font_Glyph,
    baseline: f32,
    line_advance: f32,
    padding: f32,

    load_state: Load_State,
} 

Font_Glyph :: struct {
    index: i32,
    advance: f32,
    lsb: f32,
    offset: [2]f32,
    dim: [2]f32,
    uv: [4]f32,
}

Font_Builder_Glyph :: struct {
    codepoint: rune,
    offset: [2]i32,
    box: [4]i32,
    bitmap: [^]u8,
}

Font_Glyph_Range :: [2]i32
Font_Glyph_Range_Latin :: Font_Glyph_Range{0x0020, 0x00FF}
Font_Glyph_Range_Punctuation :: Font_Glyph_Range{0x2000, 0x206F}
Font_Glyph_Range_Default :: []Font_Glyph_Range{Font_Glyph_Range_Latin, Font_Glyph_Range_Punctuation}

font_load :: proc(font: ^^Font, app: ^App, path: string, size: i32, ranges: []Font_Glyph_Range, raster_type: Font_Raster_Type, atlas_width: i32 = 2048, atlas_height: i32 = 2048, threaded: bool = true){
    if !check_load_state(cast(rawptr)font^, Font, proc(data: rawptr) {
        font := cast(^Font)data
        font_free(&font)
    }) {
        return
    }

    log.debug("Font load request at ", app_time())
    
    font^ = new(Font)
    font^.load_state = .Queued

    data := new(Font_Load_Task_Data, context.allocator)
    data.font = font
    data.path = path
    data.size = size
    data.atlas_width = atlas_width
    data.atlas_height = atlas_height
    data.raster_type = raster_type
    data.ranges = slice.clone(ranges)
    
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
    kern := stbtt.GetGlyphKernAdvance(font.data, a.index, b.index)

    return f32(kern) * font.scale 
}

font_get_render_mode :: proc(font: ^Font) -> f32 {
    switch font.raster_type {
    case .Bitmap: return 3.0
    case .SDF: return 2.0
    }
    return -1.0
}

@(private)
font_bitmap_raster :: proc(font: ^Font) -> []Font_Builder_Glyph {
    g := 0
    builder_glyphs := make([]Font_Builder_Glyph, font_glyph_range_count(font.ranges))
    for range in font.ranges {
        for r := range[0]; r <= range[1]; r += 1 {
            builder_glyphs[g].codepoint = cast(rune)r
            builder_glyphs[g].bitmap = stbtt.GetCodepointBitmapSubpixel(font.data, font.scale, font.scale, 8.0, 8.0, cast(rune)r, 
                                                 &builder_glyphs[g].box.z, &builder_glyphs[g].box.w, 
                                                 &builder_glyphs[g].offset.x, &builder_glyphs[g].offset.y)
            g += 1
        }
    }
    return builder_glyphs
}

@(private)
font_sdf_raster :: proc(font: ^Font) -> []Font_Builder_Glyph {
    font.padding = 16.0
    pixel_dist_scale : f32 = f32(127)/f32(font.padding)

    g := 0
    builder_glyphs := make([]Font_Builder_Glyph, font_glyph_range_count(font.ranges))
    for range in font.ranges {
        for r := range[0]; r <= range[1]; r += 1 {
            builder_glyphs[g].codepoint = cast(rune)r
            builder_glyphs[g].bitmap = stbtt.GetCodepointSDF(font.data, font.scale, r, i32(font.padding), 180, pixel_dist_scale, 
                                                 &builder_glyphs[g].box.z, &builder_glyphs[g].box.w, 
                                                 &builder_glyphs[g].offset.x, &builder_glyphs[g].offset.y)
            g += 1
        }
    }
    return builder_glyphs
}

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

@(private)
font_build_atlas :: proc(font: ^Font, glyphs: []Font_Builder_Glyph) {
    for i := 0; i < len(glyphs); i += 1 {
        built_glyph := &glyphs[i]

        lsb, adv: i32
        stbtt.GetCodepointHMetrics(font.data, built_glyph.codepoint, &adv, &lsb)

        glyph := Font_Glyph{
            stbtt.FindGlyphIndex(font.data, built_glyph.codepoint),
            f32(adv)*font.scale, 
            f32(lsb)*font.scale,
            [2]f32{f32(built_glyph.offset.x) + font.padding, f32(built_glyph.offset.y)},
            [2]f32{f32(built_glyph.box.z) - font.padding, f32(built_glyph.box.w) - font.padding},
            [4]f32{
                (f32(built_glyph.box.x) + font.padding/2)/f32(font.texture.w),
                (f32(built_glyph.box.y+built_glyph.box.w)-font.padding/2)/f32(font.texture.h),
                (f32(built_glyph.box.x+built_glyph.box.z)-font.padding/2)/f32(font.texture.w),
                (f32(built_glyph.box.y) + font.padding/2)/f32(font.texture.h),
            },
        }

        font.glyphs[built_glyph.codepoint] = glyph

        if built_glyph.box.z != 0 && built_glyph.box.z != 0 {
            for y : i32 = 0; y < built_glyph.box.w; y += 1 {
                for x : i32 = 0; x < built_glyph.box.z; x += 1 {
                    font.texture.data[(built_glyph.box.x + x) + font.texture.w * (built_glyph.box.y + y)] = built_glyph.bitmap[x + built_glyph.box.z * y]
                }   
            }    
        }
    }
}

@(private)
font_load_task :: proc(task: thread.Task) {
    task_data := cast(^Font_Load_Task_Data)task.data
    
    data, ok := os.read_entire_file_from_filename(task_data.path, context.allocator)
    if ok {
        font := task_data.font^
        font.size = task_data.size
        font.ranges = task_data.ranges
        font.texture = texture_create(task_data.atlas_width, task_data.atlas_height, Texture_Format.Alpha)
        font.glyphs = make(map[rune]Font_Glyph, font_glyph_range_count(font.ranges))
        font.raster_type = task_data.raster_type
        
        fontinfo := new(stbtt.fontinfo)
        if !stbtt.InitFont(fontinfo, slice.as_ptr(data), 0) {
            log.error("Failed to load font ", task_data.path, ".")
            return
        }

        font.data = fontinfo
        font.scale = stbtt.ScaleForPixelHeight(fontinfo, f32(font.size))

        ascent, descent, line_gap: i32 
        stbtt.GetFontVMetrics(fontinfo, &ascent, &descent, &line_gap)
        font.baseline = f32(ascent) * font.scale
        font.line_advance = (f32(ascent) - f32(descent) + f32(line_gap)) * font.scale

        builder_glyphs: []Font_Builder_Glyph
        switch font.raster_type {
            case .Bitmap:   builder_glyphs = font_bitmap_raster(font)
            case .SDF:      builder_glyphs = font_sdf_raster(font)
        }

        if !font_pack_rects(font, builder_glyphs) {
            log.error("Failed to pack rects while loading font!")
        }

        font_build_atlas(font, builder_glyphs)

        switch font.raster_type {
            case .Bitmap:
                for glyph in builder_glyphs {
                    stbtt.FreeSDF(glyph.bitmap, nil)
                }
            case .SDF:
                for glyph in builder_glyphs {
                    stbtt.FreeBitmap(glyph.bitmap, nil)
                }  
        }
        delete(builder_glyphs)

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
        free(font^.data)

        texture_free(&font^.texture)

        delete(font^.glyphs)

        free(font^)
        font^ = nil
    }
}

@(private)
font_glyph_count :: proc(range: Font_Glyph_Range) -> i32 {
    return i32(range.y) - i32(range.x) + 1
}

@(private)
font_glyph_range_count :: proc(ranges: []Font_Glyph_Range) -> i32 {
    total : i32 = 0
    for range in ranges {
        total += (range.y - range.x + 1)
    }
    return total
}
