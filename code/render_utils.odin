package main

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
    for r := 0; r < len(text); r += 1 {
        rune_a := rune(text[r])
        rune_b := r < len(text)-2 ? rune(text[r+1]) : rune(-1)
        glyph, ok := font.glyphs[rune_a]
        glyph_b, ok_b := font.glyphs[rune_b]
        
        if ok {
            scaling_factor := (size/f32(font.size))
            
            x := cpos.x + glyph.offset.x*scaling_factor - (first_r ? glyph.lsb*scaling_factor : 0.0)
            y := cpos.y - glyph.offset.y*scaling_factor
            eff_dim := glyph.dim * scaling_factor

            r_rect := Rect{x, y-eff_dim.y, x+eff_dim.x, y}
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
            cpos.x += (glyph.advance + extra) * scaling_factor
        }
    }

    dim := rect_dim(result)
    return {dim.x, text_line_advance(font, size)}
}

text_rect :: proc(font: ^Font, text: string, size: f32, pos: Vec2, options : Text_Render_Options = {.Center}) -> Rect {
    result := Rect{pos.x, pos.y, pos.x, pos.y}
    
    if !font_validate(font) {
        return result
    }

    first_r := true
    cpos := pos
    scaling_factor := (size/f32(font.size))
    for r := 0; r < len(text); r += 1 {
        rune_a := rune(text[r])
        rune_b := r < len(text)-2 ? rune(text[r+1]) : rune(-1)
        glyph, ok := font.glyphs[rune_a]
        glyph_b, ok_b := font.glyphs[rune_b]
        
        if ok {
            x := cpos.x + glyph.offset.x*scaling_factor - (first_r ? glyph.lsb*scaling_factor : 0.0)
            y := cpos.y - glyph.offset.y*scaling_factor
            eff_dim := glyph.dim * scaling_factor

            r_rect := Rect{x, y-eff_dim.y, x+eff_dim.x, y}
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
            cpos.x += (glyph.advance + extra) * scaling_factor
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

text_line_advance :: #force_inline proc(font: ^Font, size: f32) -> f32 {
    if !font_validate(font) {
        return 0.0
    }

    scaling_factor := (size/f32(font.size))
    return (font.line_advance) * scaling_factor
}
