package main

Text_Render_Operation :: enum {Center, Hor_Left, Hor_Right,
                               Ver_Top, Ver_Bottom}

Text_Render_Options :: bit_set[Text_Render_Operation]

text_rect :: proc(text: string, size: f32, pos: Vec2, options : Text_Render_Options = {.Center}) -> Rect {
    result := Rect{pos.x, pos.y, pos.x, pos.y}
    
    font := gl_renderer.font
    if !font_validate(font) {
        return result
    }

    first_r := true
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

    if options != {.Center} {
        result = text_rect_options_resolve(options, result)
    }

    return result
}

text_rect_options_resolve :: proc(options: Text_Render_Options, rect: Rect) -> Rect{
    result := rect
    
    half_dim := 0.5*rect_dim(rect)
    if Text_Render_Operation.Hor_Left in options {
        result.x -= half_dim.x
        result.z -= half_dim.x
    }
    if Text_Render_Operation.Hor_Right in options {
        result.x += half_dim.x
        result.z += half_dim.x
    }
    if Text_Render_Operation.Ver_Bottom in options {
        result.y += half_dim.y
        result.w += half_dim.y
    }
    if Text_Render_Operation.Ver_Top in options {
        result.y -= half_dim.y
        result.w -= half_dim.y
    }

    return result
}

text_line_advance :: #force_inline proc(size: f32) -> f32 {
    font := gl_renderer.font
    if !font_validate(font) {
        return 0.0
    }

    scaling_factor := (size/f32(font.size))

    return (font.line_advance) * scaling_factor
}
