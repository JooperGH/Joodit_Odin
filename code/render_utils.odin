package main

import "core:unicode/utf8"
import "core:math"

Text_Render_Operation :: enum {Center, Hor_Left, Hor_Right,
                               Ver_Top, Ver_Bottom}

Text_Render_Options :: bit_set[Text_Render_Operation]

text_dim :: proc(font: ^Font, text: string, size: f32) -> Vec2 {
    result := Rect{}
    
    if !font_validate(font) {
        return {}
    }

    first_r := true
    cpos := Vec2{0, 0}
    runes := utf8.string_to_runes(text, context.temp_allocator)
    la : f32 = 0.0
    for r := 0; r < len(runes); r += 1 {
        rune_a := runes[r]
        rune_b := ((len(runes) > 1) && (r < len(runes)-2)) ? runes[r+1] : rune(-1)
        glyph, ok := font.glyphs[rune_a]
        glyph_b, ok_b := font.glyphs[rune_b]
    
        if ok {
            sf, bl, la_, adv := font_glyph_metrics(font, &glyph, size)
            la = max(la, la_)
            
            x := math.floor_f32(cpos.x) + glyph.x0
            y := math.floor_f32(cpos.y) + glyph.y0
            eff_dim := sf*Vec2{glyph.x1-glyph.x0, glyph.y1-glyph.y0}

            r_rect := Rect{x, y, x+eff_dim.x, y+eff_dim.y}
            if first_r {
                result = r_rect
                first_r = false
            } else {
                result = rect_union(result, r_rect)
            }

            extra : f32 = 0.0
            if ok && ok_b {
                extra = font_glyph_kern(font, &glyph, &glyph_b)
            }
            cpos.x += adv + extra * sf 
        }
    }

    dim := rect_dim(result)
    return {dim.x, la}
}

text_rect :: proc(font: ^Font, text: string, size: f32, pos: Vec2, options : Text_Render_Options = {.Center}) -> Rect {
    result := Rect{pos.x, pos.y, pos.x, pos.y}
    
    if !font_validate(font) {
        return result
    }

    first_r := true
    cpos := pos
    runes := utf8.string_to_runes(text, context.temp_allocator)
    for r := 0; r < len(runes); r += 1 {
        rune_a := runes[r]
        rune_b := r < len(text)-1 ? runes[r+1] : rune(-1)
        glyph, ok := font.glyphs[rune_a]
        glyph_b, ok_b := font.glyphs[rune_b]
        
        if ok {
            sf, bl, la_, adv := font_glyph_metrics(font, &glyph, size)

            x := math.floor_f32(cpos.x) + glyph.x0 
            y := math.floor_f32(cpos.y) + glyph.y0
            eff_dim := sf*Vec2{glyph.x1-glyph.x0, glyph.y1-glyph.y0}

            r_rect := Rect{x, y, x+eff_dim.x, y+eff_dim.y}
            if first_r {
                result = r_rect
                first_r = false
            } else {
                result = rect_union(result, r_rect)
            }

            extra : f32 = 0.0
            if ok && ok_b {
                extra = font_glyph_kern(font, &glyph, &glyph_b)
            }
            cpos.x += adv + extra * sf 
        }
    }

    return result
}

text_rect_options_offset :: proc(options: Text_Render_Options, dim: Vec2) -> Vec2 {
    result := -0.5*dim
    if Text_Render_Operation.Hor_Left in options {
        result.x -= 0.5*dim.x
    }
    if Text_Render_Operation.Hor_Right in options {
        result.x += 0.5*dim.x
    }
    if Text_Render_Operation.Ver_Bottom in options {
        result.y -= 0.5*dim.y
    }
    if Text_Render_Operation.Ver_Top in options {
        result.y += 0.5*dim.y
    }
    return result
}
