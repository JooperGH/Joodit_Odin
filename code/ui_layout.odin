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
    Text,
    PercentParent,
    Auto,
}

UI_Size :: struct {
    kind: UI_Size_Kind,
    value: f32,
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

UI_Layout :: struct {
    axis: UI_Axis,
    next: Rect,
}

ui_widget_new_layout :: proc(widget: ^UI_Widget) {
    widget.layout = new(UI_Layout, ui.temp_allocator)
    widget.layout.next = {}
    widget.layout.axis = .Y
}

ui_widget_style_default :: proc() -> (style: UI_Style) {
    style.alpha = 1.0
    style.padding = {5.0, 5.0}
    style.rounding = 10
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

ui_size_is_kind_axis :: proc(w: ^UI_Widget, axis: UI_Axis, kind: UI_Size_Kind) -> b32 {
    return w.size[axis].kind == kind
}

ui_size_is_kind_both_axis :: proc(w: ^UI_Widget, kind: UI_Size_Kind) -> b32 {
    return w.size[.X].kind == kind || w.size[.Y].kind == kind
}

ui_size_is_kind :: proc{ui_size_is_kind_axis, ui_size_is_kind_both_axis}
