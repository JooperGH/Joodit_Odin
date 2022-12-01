package main

ui_button :: proc(text: string) -> UI_Widget_Interaction {
    widget := ui_widget_create({.Clickable,
                                .DrawBackground,
                                .DrawBorder,
                                .DrawText,
                                .HotAnimation,
                                .ActiveAnimation},
                                text)

    i := ui_widget_interaction(widget)
    
    if i.hovered {
        ui_set_as_hot(widget)
    }

    if i.left_down && ui_match_hot(widget) {
        ui_set_as_active(widget)
    }

    return i
}

ui_text :: proc(text: string) -> UI_Widget_Interaction {
    widget := ui_widget_create({.DrawText,
                                .TextAnimation,
                                .HotAnimation,
                                .ActiveAnimation},
                                text)

    i := ui_widget_interaction(widget)
    
    if i.hovered {
        ui_set_as_hot(widget)
    }

    return i
}

ui_bar :: proc(text: string) -> UI_Widget_Interaction {
    widget := ui_widget_create({.Clickable,
                                .DrawBackground,
                                .DrawBorder,
                                .HorPad,
                                .VerPad},
                                text)

    widget.semantic_sizes[.X] = {
        .PercentOfParent,
        1.0,
        0.0,
    }
    widget.semantic_sizes[.Y] = {
        .Pixels,
        text_line_advance(ui.font, ui.font_size),
        0.0,
    }

    i := ui_widget_interaction(widget)
    return i
}

ui_panel :: proc(text: string) -> UI_Widget_Interaction {
    widget := ui_widget_create({.Clickable,
                                .DrawBackground,
                                .DrawBorder,
                                .HorPad,
                                .VerPad,
                                .HotAnimation,
                                .ActiveAnimation},
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

    i := ui_widget_interaction(widget)
    return i
}

ui_spacer :: proc() {
    w := ui_widget_create({.Ignore}, "")

    assert(!(.FillX in w.flags && .FillY in w.flags))

    if .FillX in w.flags {
        w.semantic_sizes[.X] = {
            .LeftoverChildSum,
            1.0,
            0.0,
        }
        w.semantic_sizes[.Y] = {
            .PercentOfParent,
            1.0,
            0.0,
        }
    } else if (.FillY in w.flags) || (.FillX not_in w.flags && .FillX not_in w.flags) {
        w.semantic_sizes[.X] = {
            .PercentOfParent,
            1.0,
            0.0,
        }
        w.semantic_sizes[.Y] = {
            .LeftoverChildSum,
            1.0,
            0.0,
        }
    }
}