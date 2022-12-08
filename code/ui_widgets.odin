package main

import "core:log"
import "core:math"

ui_slider_f32 :: proc(text: string, value: ^f32, min: f32, max: f32) -> ^UI_Widget {
    widget := ui_widget({.DrawBackground,
                        .DrawBorder,
                        .FillY},
                        text)
    widget.semantic_sizes[.X] = {
        .LeftoverChildSum,
        0.5,
        0.9,
    }
    widget.semantic_sizes[.Y] = {
        .PercentOfParent,
        1.0,
        0.0,
    }

    ui_push_parent(widget)



    ui_pop_parent()
    
    return widget
}

ui_button :: proc(text: string) -> ^UI_Widget {
    widget := ui_widget({.Clickable,
                        .DrawBackground,
                        .DrawBorder,
                        .DrawText,
                        .CenterX,
                        .CenterY,
                        .HotAnimation,
                        .ActiveAnimation,
                        .FillY},
                        text)
    widget.active_condition = proc(w: ^UI_Widget) -> b32 {
        return w.i.left_clicked
    }
    widget.semantic_sizes[.Y] = {
        .PercentOfParent,
        1.0,
        0.0,
    }
    return widget
}

ui_text :: proc(text: string) -> ^UI_Widget {
    widget := ui_widget({.DrawText,
                        .TextAnimation,
                        .HotAnimation,
                        .ActiveAnimation,
                        .FillY},
                        text)

    return widget
}

ui_bar :: proc(text: string) -> ^UI_Widget {
    widget := ui_widget({.Clickable,
                        .DrawBackground,
                        .DrawBorder,
                        .FillY},
                        text)
    widget.active_condition = proc(w: ^UI_Widget) -> b32 {
        return w.i.left_down
    }

    widget.semantic_sizes[.X] = {
        .PercentOfParent,
        1.0,
        0.0,
    }
    widget.semantic_sizes[.Y] = {
        .Pixels,
        ui.font.line_advance,
        0.0,
    }

    return widget
}

ui_panel :: proc(text: string) -> ^UI_Widget {
    widget := ui_widget({.DrawBackground,
                        .DrawBorder,
                        .FillY},
                        text)
                            
    widget.semantic_sizes[.X] = {
        .PercentOfParent,
        1.0,
        0.0,
    }
    widget.semantic_sizes[.Y] = {
        .PercentOfParent,
        1.0,
        0.0,
    }

    widget.style.gradient = false
    widget.style.colors[.Border] = {1.0, 1.0, 0.0, 1.0}

    return widget
}

ui_spacer :: proc(free_space_ratio: f32 = 0.0, threshold: f32 = 0.9) {
    w := ui_widget({.Ignore}, "")
    assert(!(.FillX in w.flags && .FillY in w.flags))
    if .FillX in w.flags {
        w.semantic_sizes[.X].kind = .LeftoverChildSum
        w.semantic_sizes[.X].value = free_space_ratio
        w.semantic_sizes[.X].threshold = threshold
    }
    if .FillY in w.flags {
        w.semantic_sizes[.Y].kind = .LeftoverChildSum
        w.semantic_sizes[.Y].value = free_space_ratio
        w.semantic_sizes[.Y].threshold = threshold
    }
}

ui_begin_row :: proc() {
    ui_push_flags({.FillX}, {.FillY})
}

ui_end_row :: proc() {
    ui_pop_flags()
}