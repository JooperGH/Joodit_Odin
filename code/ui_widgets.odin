package main

import "core:log"
import "core:math"

ui_box :: proc(str: string, x, y: UI_Size) -> ^UI_Widget {
    widget := ui_widget(
        {
            .DrawBackground, 
        }, str)
    widget.size[.X] = x
    widget.size[.Y] = y
    return widget
}

ui_button :: proc(str: string, y: UI_Size = {.Text, 1.5}, x: UI_Size = {.Text, 1.3}) -> ^UI_Widget {
    widget := ui_widget(
        {
            .Clickable, 
            .DrawBackground, 
            .DrawBorder, 
            .DrawText, 
            .TextCenterX,
            .TextCenterY,
            .HotAnimation, 
            .ActiveAnimation,
        }, str)
    widget.hot_condition = proc(w: ^UI_Widget) -> b32 {
        return w.i.hovered
    }
    widget.active_condition = proc(w: ^UI_Widget) -> b32 {
        return w.i.left_down
    }
    widget.size[.X] = x
    widget.size[.Y] = y
    return widget
}

ui_widget_is_spacer :: #force_inline proc(w: ^UI_Widget) -> b32 {
    return ui_match_null(w) && (.AxisToggle not_in w.flags)
}

ui_widget_is_row ::  #force_inline proc(w: ^UI_Widget) -> b32 {
    return ui_match_null(w) && (.AxisToggle in w.flags)
}

ui_spacer :: proc(space: f32) {
    spacer := ui_widget({.Ignore}, "")
    spacer.size[.X] = ui_widget_size(.Pixels, space)
    spacer.size[.Y] = ui_widget_size(.Pixels, space)
}

ui_auto_spacer :: proc() {
    spacer := ui_widget({.Ignore}, "")
    spacer.size[.X] = ui_widget_size(.Auto)
    spacer.size[.Y] = ui_widget_size(.Auto)
}

ui_row_begin :: proc() {
    ui_widget({.Ignore, .AxisToggle}, "")
}

ui_row_end :: proc() {
    ui_widget({.Ignore, .AxisToggle}, "")
}

/*
ui_slider_f32 :: proc(text: string, value: ^f32, min: f32, max: f32) -> ^UI_Widget {
    widget := ui_widget({.DrawBackground,
                        .DrawBorder,
                        .FillY},
                        text)
    widget.size[.X] = {
        .MinSibling,
        0.5,
    }
    widget.size[.Y] = {
        .PercentParent,
        1.0,
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
    widget.size[.Y] = {
        .Pixels,
        ui.font.line_advance,
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

    widget.size[.X] = {
        .PercentParent,
        1.0,
    }
    widget.size[.Y] = {
        .MaxChildren,
        1.0,
    }

    return widget
}

ui_panel_space :: proc(text: string) -> ^UI_Widget {
    widget := ui_widget({.FillY},
                        text)
    widget.size[.X] = {
        .MinSibling,
        1.0,
    }
    widget.size[.Y] = {
        .MinSibling,
        1.0,
    }

    return widget
}

ui_panel :: proc(text: string) -> ^UI_Widget {
    widget := ui_widget({.DrawBackground,
                        .DrawBorder,
                        .FillY},
                        text)
                            
    widget.size[.X] = {
        .MinSibling,
        1.0,
    }
    widget.size[.Y] = {
        .MinSibling,
        1.0,
    }

    widget.style.gradient = false

    return widget
}

ui_spacer :: proc(space: Vec2) {
    w := ui_widget({.Ignore}, "")
    assert(!(.FillX in w.flags && .FillY in w.flags))
    if .FillX in w.flags {
        w.size[.X].kind = .Pixels
        w.size[.X].value = space.x
        }
    if .FillY in w.flags {
        w.size[.Y].kind = .Pixels
        w.size[.Y].value = space.y
    }
}

ui_begin_row :: proc() {
    ui_push_flags({.FillX}, {.FillY})
}

ui_end_row :: proc() {
    ui_pop_flags()
}
*/