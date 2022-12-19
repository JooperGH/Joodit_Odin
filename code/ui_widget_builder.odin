package main

import "core:slice"
import "core:strings"
import "core:hash"
import "core:fmt"
import "core:math"
import "core:mem"

UI_Widget_Interaction :: struct {
    widget: ^UI_Widget,
    mouse_pos: Vec2,
    mouse_drag: Vec2,

    left_clicked: b32,
    left_double_clicked: b32,
    left_down: b32,
    left_released: b32,
    
    right_clicked: b32,
    right_double_clicked: b32,
    right_down: b32,
    right_released: b32,
    
    dragged: b32,
    hovered: b32,
}

UI_Widget_Flag :: enum {
    Ignore,
    AxisToggle,
    TextCenterX,
    TextCenterY,
    Clickable,
    Draggable,
    DrawBackground,
    DrawBorder,
    DrawText,
    TextAnimation,
    HotAnimation,
    ActiveAnimation,
}

UI_Widget_Flags :: bit_set[UI_Widget_Flag]

UI_Widget :: struct {
    first: ^UI_Widget,
    last: ^UI_Widget,
    next: ^UI_Widget,
    prev: ^UI_Widget,
    parent: ^UI_Widget,

    hash_next: ^UI_Widget,
    hash_prev: ^UI_Widget, 

    id: UI_ID,
    str: string,
    flags: UI_Widget_Flags,

    style: UI_Style,
    
    size: [UI_Axis]UI_Size,
    calc_size: Vec2,
    rect: Rect,
    offset: Vec2,
    layout: ^UI_Layout,

    dragging: b32,
    hot_t: f32,
    active_t: f32,

    i: UI_Widget_Interaction,
    active_condition: UI_Condition_Fn,
    hot_condition: UI_Condition_Fn,
}

UI_Condition_Fn :: proc(^UI_Widget) -> b32

ui_match_id :: #force_inline proc(a, b: UI_ID) -> b32 {
    return a == b
}

ui_match_null :: #force_inline proc(widget: ^UI_Widget) -> b32 {
    return widget.id == ui.widgets.id_null
}

ui_match_hot :: #force_inline proc(widget: ^UI_Widget) -> b32 {
    return widget.id == ui.widgets.id_hot
}

ui_match_active :: #force_inline proc(widget: ^UI_Widget) -> b32 {
    return widget.id == ui.widgets.id_active
}

ui_set_as_hot :: #force_inline proc(widget: ^UI_Widget) {
    ui.widgets.id_hot = widget.id    
    widget.hot_t = 1.0
}

ui_set_as_active :: #force_inline proc(widget: ^UI_Widget) {
    ui.widgets.id_active = widget.id    
    widget.active_t = 1.0  
}

ui_get_id :: proc(name: string) -> (id: UI_ID, name_clean: string) {
    sep_at := strings.index(name, "###")
    if sep_at != -1 {
        name_clean = name[:sep_at]
        id = cast(UI_ID)hash.crc32(transmute([]u8)name[sep_at:])
        return
    }

    sep_at = strings.index(name, "##")
    if sep_at != -1 {
        name_clean = name[:sep_at]
        id = cast(UI_ID)hash.crc32(transmute([]u8)name)
    } else {
        name_clean = name
        id = cast(UI_ID)hash.crc32(transmute([]u8)name)
    }
    return
}

ui_push_parent :: proc(widget: ^UI_Widget) {
    append(&ui.widgets.parents, widget)
}

ui_pop_parent :: proc() {
    assert(len(ui.widgets.parents) > 0)
    pop(&ui.widgets.parents)
}

ui_push_flags :: proc(flags_add: UI_Widget_Flags, flags_rem: UI_Widget_Flags = {}) {
    append(&ui.widgets.fl_adds, flags_add)
    append(&ui.widgets.fl_rems, flags_rem)
}

ui_pop_flags :: proc() {
    assert(len(ui.widgets.fl_adds) > 0)
    assert(len(ui.widgets.fl_rems) > 0)
    pop(&ui.widgets.fl_adds)
    pop(&ui.widgets.fl_rems)
}

ui_widget_alloc :: proc(id: UI_ID, str: string, allocator: mem.Allocator) -> ^UI_Widget {
    widget := new(UI_Widget, allocator)
    widget.id = id
    widget.str = str
    return widget
}

ui_widget_get :: proc(str: string) -> ^UI_Widget {
    id, name := ui_get_id(str)

    if id == ui.widgets.id_null {
        return ui_widget_alloc(id, str, ui.temp_allocator)
    }

    widget, ok := ui.widgets.all[id]
    if !ok {
        widget = ui_widget_alloc(id, str, ui.allocator)
        ui.widgets.all[id] = widget
    }
    
    return widget
}

ui_widget_build_hierarchy :: proc(widget: ^UI_Widget) {
    if ui.widgets.first == nil {
        widget.hash_prev = nil
        widget.hash_next = nil
        ui.widgets.first = widget
        ui.widgets.last = widget
    } else {
        widget.hash_next = nil
        widget.hash_prev = ui.widgets.last
        ui.widgets.last.hash_next = widget
        ui.widgets.last = widget
    }

    widget.parent = len(ui.widgets.parents) > 0 ? slice.last(ui.widgets.parents[:]) : nil 
    if widget.parent != nil {
        if widget.parent.first == nil {
            widget.parent.first = widget
            widget.parent.last = widget
        } else {
            widget.next = nil
            widget.prev = widget.parent.last
            widget.parent.last.next = widget
            widget.parent.last = widget
        }
    }
}

ui_widget_create :: proc(str: string) -> ^UI_Widget {
    widget := ui_widget_get(str)
    ui_widget_build_hierarchy(widget)
    return widget
}

ui_widget_flags :: proc(flags: UI_Widget_Flags) -> UI_Widget_Flags {
    return flags + (len(ui.widgets.fl_adds) > 0 ? slice.last(ui.widgets.fl_adds[:]) : {}) - (len(ui.widgets.fl_rems) > 0 ? slice.last(ui.widgets.fl_rems[:]) : {})
}

ui_widget_size :: #force_inline proc(kind: UI_Size_Kind, value: f32 = 1.0) -> UI_Size {
    return {kind, value}
}

ui_widget :: proc(flags: UI_Widget_Flags, str: string) -> ^UI_Widget {
    widget := ui_widget_create(str)
    if widget == nil do return widget
    
    widget.flags = ui_widget_flags(flags)
    widget.style = ui_widget_style_default()
    widget.size[.X] = ui_widget_size(.Pixels, 100.0)
    widget.size[.Y] = ui_widget_size(.Pixels, 100.0)
    return widget
}

ui_widget_interaction :: proc(widget: ^UI_Widget) -> UI_Widget_Interaction {
    clickable : b32 = .Clickable in widget.flags
    draggable : b32 = .Draggable in widget.flags

    i := UI_Widget_Interaction{}
    i.widget = widget
    i.mouse_pos = ui.mouse_pos
    i.mouse_drag = ui.mouse_dpos
    i.hovered = rect_point_inside(widget.rect, ui.mouse_pos)
    i.left_clicked = clickable && i.hovered && ui_input_pressed(Button_Code.Left)
    i.left_double_clicked = clickable && i.hovered && ui_input_double_pressed(Button_Code.Left)
    i.left_down = clickable && i.hovered && ui_input_down(Button_Code.Left)
    i.left_released = clickable && ui_input_released(Button_Code.Left)
    i.right_clicked = clickable && i.hovered && ui_input_pressed(Button_Code.Right)
    i.right_double_clicked = clickable && i.hovered && ui_input_double_pressed(Button_Code.Right)
    i.right_down = clickable && i.hovered && ui_input_down(Button_Code.Right)
    i.right_released = clickable && ui_input_released(Button_Code.Right)

    if clickable && draggable && i.hovered && ui_input_pressed(Button_Code.Left) {
        widget.dragging = true
    }
    if clickable && draggable && ui_input_released(Button_Code.Left) {
        widget.dragging = false
    }

    i.dragged = clickable && draggable && widget.dragging && ui_input_down(Button_Code.Left)
    return i
}

ui_widget_hot_anim :: proc(widget: ^UI_Widget, threshold: f32 = 0.5, rate: f32 = 6.0) -> f32 {
    return .ActiveAnimation in widget.flags ? 1.0/(1.0+math.exp_f32(-rate*(widget.hot_t-threshold))) : 0.0
}

ui_widget_active_anim :: proc(widget: ^UI_Widget, threshold: f32 = 0.5, rate: f32 = 6.0) -> f32 {
    return .ActiveAnimation in widget.flags ? 1.0/(1.0+math.exp_f32(-rate*(widget.active_t-threshold))) : 0.0
}

ui_widget_anim :: proc(widget: ^UI_Widget, threshold: f32 = 0.5, rate: f32 = 6.0) -> f32 {
    x := (1.0/3.0)*widget.hot_t + (2.0/3.0)*widget.active_t
    return 1.0/(1.0+math.exp_f32(-rate*(x-threshold)))
}
