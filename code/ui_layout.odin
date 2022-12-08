package main

import "core:mem"
import "core:log"

UI_Axis :: enum {
    X,
    Y,
}

UI_Size_Kind :: enum {
    Null,
    Pixels,
    TextContent,
    PercentOfParent,
    LeftoverChildSum,
}

UI_Size :: struct {
    kind: UI_Size_Kind,
    value: f32,
    threshold: f32,
}

UI_Color :: enum {
    Bg,
    BgGradient0,
    BgGradient1,
    Border,
    TextColor,
    HotTextColor,
    ActiveTextColor,
}

UI_Style :: struct {
    alpha: f32,
    padding: Vec2,
    rounding: f32,
    border_size: f32,
    gradient: b32,
    colors: [UI_Color]Color,
}

ui_style_default :: proc() -> (style: UI_Style) {
    style.alpha = 1.0
    style.padding = {5.0, 5.0}
    style.rounding = 2.0
    style.border_size = 1.0
    style.gradient = true
    style.colors[.Bg] = {0.2, 0.2, 0.225, 1.0}
    style.colors[.BgGradient0] = style.colors[.Bg]
    style.colors[.BgGradient1] = {0.25, 0.25, 0.275, 1.0}
    style.colors[.Border] = {0.6, 0.6, 0.6, 1.0}
    style.colors[.TextColor] = {1.0, 1.0, 1.0, 1.0}
    style.colors[.HotTextColor] = {1.0, 1.0, 0.5, 1.0}
    style.colors[.ActiveTextColor] = {1.0, 1.0, 0.0, 1.0}
    return
}

ui_layout_root :: proc(w: ^UI_Widget) {
    #partial switch w.semantic_sizes[.X].kind {
        case .Pixels:             w.size.x = w.semantic_sizes[.X].value
        case .PercentOfParent:    w.size.x = w.semantic_sizes[.X].value * ui.app.window_size.x
        case:                     log.debug("Semantic size kind not supported for root node.")
    }
    #partial switch w.semantic_sizes[.Y].kind {
        case .Pixels:             w.size.y = w.semantic_sizes[.Y].value
        case .PercentOfParent:    w.size.y = w.semantic_sizes[.Y].value * ui.app.window_size.y
        case:                     log.debug("Semantic size kind not supported for root node.")
    }

    if w.size.x > ui.app.window_size.x  {
        w.size.x = ui.app.window_size.x
    }
    if w.size.y > ui.app.window_size.y {
        w.size.y = ui.app.window_size.y
    }

    w.pos = {0, 0}
    w.rect = rect_from_pos_dim(w.pos, w.size)
    w.available_rect = w.rect
}

ui_size_is_kind_axis :: proc(w: ^UI_Widget, axis: UI_Axis, kind: UI_Size_Kind) -> b32 {
    return w.semantic_sizes[axis].kind == kind
}

ui_size_is_kind_both_axis :: proc(w: ^UI_Widget, kind: UI_Size_Kind) -> b32 {
    return w.semantic_sizes[.X].kind == kind || w.semantic_sizes[.Y].kind == kind
}

ui_size_is_kind :: proc{ui_size_is_kind_axis, ui_size_is_kind_both_axis}

ui_widget_calc_pad :: proc(w: ^UI_Widget) -> Vec2 {
    return {
        .PadX in w.flags ? w.style.padding.x : 0.0,
        .PadY in w.flags ? w.style.padding.y : 0.0,
    }
}

/*
ui_layout_calc_size :: proc(w: ^UI_Widget) -> Vec2 {
    size := Vec2{0, 0}

    parent := w.parent
    
    empty_space := Vec2{0, 0}
    children_sum := Vec2{0, 0}
    null_count : f32 = 0.0
    if w.semantic_sizes[.X].kind == .LeftoverChildSum || w.semantic_sizes[.Y].kind == .LeftoverChildSum {
        sentinel := parent.first
        for sentinel != nil {
            if !ui_match_null(sentinel) {
                children_sum += ui_layout_calc_size(sentinel)
            } else {
                null_count += 1.0
            }
            sentinel = sentinel.next
        }
    }
    empty_space = rect_dim(parent.available_rect) - children_sum    

    text_content_dim := Vec2{0, 0}
    if w.semantic_sizes[.X].kind == .TextContent || w.semantic_sizes[.Y].kind == .TextContent {
        text_content_dim = text_dim(ui.font, w.str, ui.font_size)
    }

    available_rect := parent.available_rect
    available_dim := rect_dim(parent.available_rect)
    
    #partial switch w.semantic_sizes[.X].kind {
        case .Pixels:             size.x = w.semantic_sizes[.X].value
        case .PercentOfParent:    size.x = w.semantic_sizes[.X].value * available_dim.x
        case .TextContent:        size.x = text_content_dim.x
        case .LeftoverChildSum:   size.x = null_count == 0.0 ? empty_space.x : empty_space.x/null_count
        case:                     log.debug("Semantic size kind not supported for root node.")
    }
    #partial switch w.semantic_sizes[.Y].kind {
        case .Pixels:             size.y = w.semantic_sizes[.Y].value
        case .PercentOfParent:    size.y = w.semantic_sizes[.Y].value * available_dim.y
        case .TextContent:        size.y = max(text_content_dim.y, text_line_advance(ui.font, ui.font_size))
        case .LeftoverChildSum:   size.x = null_count == 0.0 ? empty_space.y : empty_space.y/null_count
        case:                     log.debug("Semantic size kind not supported for root node.")
    }

    pad := ui_layout_calc_pad(w)

    if size.x + pad.x > available_dim.x  {
        size.x = available_dim.x - pad.x
    }
    if size.y + pad.y > available_dim.y {
        size.y = available_dim.y - pad.y
    }

    return size
}

ui_layout_calc_pos :: proc(w: ^UI_Widget) {
    parent := w.parent
    
    pad := ui_layout_calc_pad(w)

    if .FillX in w.flags {
        last_rect := Rect{}
        sentinel := parent.first

        if sentinel != w {
            for sentinel != nil {
                if sentinel.next == w {
                    last_rect = sentinel.rect
                    break
                }
                sentinel = sentinel.next
            }
        } else {
            sentinel = nil
        }

        if sentinel == nil {
            prect := parent.available_rect
            w.pos = Vec2{prect.x + 0.5*pad.x, prect.w-w.size.y-0.5*pad.y}
            parent.available_rect.w -= w.size.y + pad.y
        } else {
            w.pos = last_rect.zy + Vec2{pad.x, 0}
            w.size.y = rect_dim(last_rect).y
        }
    } else if (.FillX in w.flags && .FillY in w.flags) || (.FillY in w.flags) || (.FillX not_in w.flags && .FillY not_in w.flags) {
        prect := parent.available_rect
        w.pos = Vec2{prect.x + 0.5*pad.x, prect.w-w.size.y-0.5*pad.y}
        parent.available_rect.w -= w.size.y + pad.y
    }   

    w.pos += w.offset
}
*/