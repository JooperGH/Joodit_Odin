package assets

import "core:log"
import "core:fmt"
import "core:os"
import "core:thread"
import "core:sort"

import stbtt "vendor:stb/truetype"

import "../platform"

Font :: struct {
    size: i32,
    texture: ^Texture,

    load_state: Load_State,
} 

Font_Glyph :: struct {
    x0, y0, x1, y1: f32,
    u0, v0, u1, v1: f32,
}

Font_Load_Task_Data :: struct {
    font: ^^Font,
    path: string,
    size: i32,
    atlas_width: i32,
    atlas_height: i32,
}

Font_Builder_Glyph_Rect :: struct {
    x, y, w, h: i32,
}

Font_Builder_Glyph_Bitmap :: struct {
    bitmap: [^]u8,
    rect: Font_Builder_Glyph_Rect,
    xoff, yoff: i32,
}

Font_Builder_Glyph_Range :: [2]i32

font_load :: proc(font: ^^Font, app: ^platform.App, path: string, size: i32, atlas_width: i32 = 2048, atlas_height: i32 = 2048){
    if !check_load_state(cast(rawptr)font^, Font, proc(data: rawptr) {
        font_free(cast(^Font)data)
    }) {
        return
    }

    log.debug("Font load request at ", platform.app_time())
    
    font^ = new(Font)
    font^.load_state = .Queued

    data := new(Font_Load_Task_Data, context.allocator)
    data.font = font
    data.path = path
    data.size = size
    data.atlas_width = atlas_width
    data.atlas_height = atlas_height
    platform.app_push_task(app, font_load_task, cast(rawptr)data)
}

@(private)
font_load_task :: proc(task: thread.Task) {
    task_data := cast(^Font_Load_Task_Data)task.data
    
    data, ok := os.read_entire_file_from_filename(task_data.path, context.allocator)
    if ok {
        font := task_data.font^
        font.size = task_data.size
        
        fontinfo := stbtt.fontinfo{}
        if !stbtt.InitFont(&fontinfo, &data[0], 0) {
            log.error("Failed to load font ", task_data.path, ".")
            return
        }
        
        font.texture = new(Texture, context.allocator)
        texture_init(font.texture, task_data.atlas_width, task_data.atlas_height, Texture_Format.Alpha)

        scale : f32 = stbtt.ScaleForPixelHeight(&fontinfo, f32(font.size))
        padding : i32 = 5
        pixel_dist_scale : f32 = f32(180)/f32(padding)

        range_latin := Font_Builder_Glyph_Range{0x0020, 0x00FF}
        range_punct := Font_Builder_Glyph_Range{0x2000, 0x206F}
        num_glyphs := glyph_range_size(range_latin) + glyph_range_size(range_punct)

        glyphs := make([]Font_Builder_Glyph_Bitmap, num_glyphs, context.allocator)
        unicode_to_idx := make([]u32, num_glyphs, context.allocator)

        width, height, xoff, yoff : i32 = ---, ---, ---, ---
        g := 0
        for i := range_latin.x; i <= range_latin.y; i += 1 {
            unicode_to_idx[g] = u32(i)
            glyphs[g].bitmap = stbtt.GetCodepointSDF(&fontinfo,
                                                     scale,
                                                     i,
                                                     padding,
                                                     180, 
                                                     pixel_dist_scale,
                                                     &glyphs[g].rect.w, 
                                                     &glyphs[g].rect.h, 
                                                     &glyphs[g].xoff, 
                                                     &glyphs[g].yoff)
            g += 1
        }
        for i := range_punct.x; i <= range_punct.y; i += 1 {
            unicode_to_idx[g] = u32(i)
            glyphs[g].bitmap = stbtt.GetCodepointSDF(&fontinfo,
                                                     scale,
                                                     i,
                                                     padding,
                                                     180, 
                                                     pixel_dist_scale,
                                                     &glyphs[g].rect.w, 
                                                     &glyphs[g].rect.h, 
                                                     &glyphs[g].xoff, 
                                                     &glyphs[g].yoff)
            g += 1
        }

        sort.quick_sort_proc(glyphs, compare_glyph_bitmap_by_height)
        x, y, mh : i32 = 0, 0, 0
        for i : i32 = 0; i < num_glyphs; i += 1 {
            rect := &glyphs[i].rect

            if x + rect.w > font.texture.w {
                y += mh
                x = 0
                mh = 0
            }

            if y + rect.h > font.texture.h {
                // TODO: Figure out how to handle failure!
                task_data.font^ = nil
                break
            }

            rect.x = x
            rect.y = y

            x += rect.w

            if rect.h > mh {
                mh = rect.h
            }
        }

        for i : i32 = 0; i < num_glyphs; i += 1 {
            glyph := &glyphs[i]

            if glyph.rect.w != 0 && glyph.rect.h != 0 {
                for y : i32 = 0; y < glyph.rect.h; y += 1 {
                    for x: i32 = 0; x < glyph.rect.w; x += 1 {
                        src := glyph.bitmap[x + glyph.rect.w * y]
                        font.texture.data[(glyph.rect.x + x) + font.texture.w * (glyph.rect.y + y)] = src
                    }   
                }    
            }
        }

        delete(data)

        for glyph in glyphs {
            stbtt.FreeSDF(glyph.bitmap, nil)
        }  
        delete(glyphs)

        font.load_state = .Loaded_And_Not_Uploaded
		log.debug("Font load request succeeded at ", platform.app_time())
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

font_free :: proc(font: ^Font) {
    if font != nil {
        texture_free(font.texture)
    }
}

@(private)
glyph_range_size :: proc(range: Font_Builder_Glyph_Range) -> i32 {
    return range.y - range.x + 1
}

@(private)
compare_glyph_bitmap_by_height :: proc(a: Font_Builder_Glyph_Bitmap, b: Font_Builder_Glyph_Bitmap) -> int {
    return a.rect.h < b.rect.h ? 0 : 1
}