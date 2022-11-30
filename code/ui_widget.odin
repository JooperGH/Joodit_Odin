package main

import "core:slice"
import "core:strings"
import "core:hash"
import "core:fmt"
import "core:math"

UI_Widget_Flag :: enum {
    Ignore,
    HorPad,
    VerPad,
    Clickable,
    DrawBorder,
    DrawText,
    DrawBackground,
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
    rect: Rect,

    hot_t: f32,
    active_t: f32,
}

ui_match_id :: #force_inline proc(a, b: UI_ID) -> b32 {
    return a == b
}

ui_match_null :: #force_inline proc(widget: ^UI_Widget) -> b32 {
    return widget.id == ui.null
}

ui_match_hot :: #force_inline proc(widget: ^UI_Widget) -> b32 {
    return widget.id == ui.hot
}

ui_match_active :: #force_inline proc(widget: ^UI_Widget) -> b32 {
    return widget.id == ui.active
}

ui_set_as_hot :: #force_inline proc(widget: ^UI_Widget) {
    ui.hot = widget.id    
    widget.hot_t = 1.0
}

ui_set_as_active :: #force_inline proc(widget: ^UI_Widget) {
    ui.active = widget.id    
    widget.active_t = 1.0  
}

ui_get_id :: proc(name: string) -> (id: UI_ID, name_clean: string) {
    sep_at := strings.index(name, "###")
    if sep_at != -1 {
        name_clean = name[:sep_at]
        id = cast(UI_ID)hash.crc32(transmute([]u8)name[:sep_at])
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
    append(&ui.parent_stack, widget)
}

ui_pop_parent :: proc() {
    assert(len(ui.parent_stack) > 0)
    pop(&ui.parent_stack)
}

ui_widget_get_from_hash :: proc(str: string) -> ^UI_Widget {
    id, name := ui_get_id(str)
    if id == ui.null {
        return nil
    }

    widget := &ui.hash[(cast(u32)id % u32(len(ui.hash)-1))]
    if widget.id != ui.null && id != ui.null {
        if widget.id != id {
            sentinel := widget
            last_non_nil_sentinel := sentinel
    
            for sentinel != nil {
                if sentinel.id == id {
                    widget = sentinel
                    break
                }
    
                if sentinel.hash_next == nil do last_non_nil_sentinel = sentinel
                sentinel = sentinel.hash_next
            }
    
            if sentinel == nil {
                widget = new(UI_Widget, ui.allocator)
                widget.id = id
                last_non_nil_sentinel.hash_next = widget
            }
        } 
    }

    widget.id = id
    widget.str = name
    widget.parent = len(ui.parent_stack) > 0 ? slice.last(ui.parent_stack[:]) : nil 
    if widget.parent != nil {
        if widget.parent.first == nil {
            assert(widget.last == nil)
            widget.parent.first = widget
            widget.parent.last = widget
        } else {
            widget.next = nil
            widget.prev = widget.parent.last
            widget.parent.last.next = widget
            widget.parent.last = widget
        }
    }
    return widget
}

ui_widget_create_root :: proc(str: string) -> ^UI_Widget {
    widget := ui_widget_get_from_hash(str)
    widget.id, widget.str = ui_get_id(str)
    widget.style = ui_style_default()
    widget.rect = {5.0, 5.0, ui.window_size.x-5.0, ui.window_size.y-5.0}
    widget.flags = {.Ignore}
    return widget
}

ui_widget_create :: proc(flags: UI_Widget_Flags, str: string) -> ^UI_Widget {
    widget := ui_widget_get_from_hash(str)
    if widget == nil do return widget
    
    widget.flags = flags
    if widget.parent != nil {
        widget.style = ui_style_default()
        if .DrawText in widget.flags {
            text_dim := text_dim(ui.font, widget.str, ui.font_size)
            widget.rect = {widget.parent.rect.x, widget.parent.rect.w-text_dim.y, widget.parent.rect.x + text_dim.x, widget.parent.rect.w}
            widget.parent.rect = {widget.parent.rect.x, widget.parent.rect.y, widget.parent.rect.z, widget.rect.y}
        } else {
            widget.rect = {widget.parent.rect.x, widget.parent.rect.y - 50.0, widget.parent.rect.x + 100.0, widget.parent.rect.y}
            widget.parent.rect = {widget.parent.rect.x, widget.parent.rect.y, widget.parent.rect.z, widget.rect.y}
        }

    }
    
    return widget
}

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

ui_widget_interaction :: proc(widget: ^UI_Widget) -> UI_Widget_Interaction {
    clickable : b32 = .Clickable in widget.flags
    i := UI_Widget_Interaction{}
    i.widget = widget
    i.mouse_pos = ui.mouse_pos
    i.mouse_drag = ui.mouse_dpos
    i.hovered = rect_point_inside(widget.rect, ui.mouse_pos)
    i.left_clicked = clickable && i.hovered && ui_input_pressed(Button_Code.Left)
    i.left_double_clicked = clickable && i.hovered && ui_input_double_pressed(Button_Code.Left)
    i.left_down = clickable && i.hovered && ui_input_down(Button_Code.Left)
    i.left_released = clickable && i.hovered && ui_input_released(Button_Code.Left)
    i.right_clicked = clickable && i.hovered && ui_input_pressed(Button_Code.Right)
    i.right_double_clicked = clickable && i.hovered && ui_input_double_pressed(Button_Code.Right)
    i.right_down = clickable && i.hovered && ui_input_down(Button_Code.Right)
    i.right_released = clickable && i.hovered && ui_input_released(Button_Code.Right)
    i.dragged = clickable && i.left_down && (app_time() - ui.buttons[Button_Code.Left].last_press > 0.3)
    return i
}

ui_widget_hot_anim :: proc(widget: ^UI_Widget, threshold: f32 = 0.5, rate: f32 = 6.0) -> f32 {
    return 1.0/(1.0+math.exp_f32(-rate*(widget.hot_t-threshold)))
}

ui_widget_hot_active :: proc(widget: ^UI_Widget, threshold: f32 = 0.5, rate: f32 = 6.0) -> f32 {
    return 1.0/(1.0+math.exp_f32(-rate*(widget.active_t-threshold)))
}

ui_widget_anim :: proc(widget: ^UI_Widget, threshold: f32 = 0.5, rate: f32 = 6.0) -> f32 {
    x := (1.0/3.0)*widget.hot_t + (2.0/3.0)*widget.active_t
    return 1.0/(1.0+math.exp_f32(-rate*(x-threshold)))
}
