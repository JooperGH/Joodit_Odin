package main

Vec2 :: [2]f32
Vec3 :: [3]f32
Vec4 :: [4]f32
Mat4 :: [16]f32
Rect :: [4]f32
Color :: [4]f32
Gradient :: [2]Color

next_pow_2 :: #force_inline proc(v: u32) -> u32 {
    result := v
    result -= 1
    result |= result >> 1
    result |= result >> 2
    result |= result >> 4
    result |= result >> 8
    result |= result >> 16
    result += 1
    return result
}

rect_center :: #force_inline proc(r: Rect) -> Vec2 {
    half_dim := 0.5*rect_dim(r)
    return r.xy + half_dim
}

rect_dim :: #force_inline proc(r: Rect) -> Vec2 {
    return Vec2{r.z-r.x, r.w-r.y}
}

rect_from_center_dim :: #force_inline proc(center: Vec2, dim: Vec2) -> Rect {
    return {center.x - 0.5*dim.x, 
             center.y - 0.5*dim.y,
             center.x + 0.5*dim.x,
             center.y + 0.5*dim.y}
}

rect_union :: #force_inline proc(a: Rect, b: Rect) -> Rect {
    return {min(a.x, b.x),
            min(a.y, b.y),
            max(a.z, b.z),
            max(a.w, b.w)}
}

rect_point_inside :: #force_inline proc(a: Rect, b: Vec2) -> b32 {
    return b.x >= a.x && b.x <= a.z && b.y >= a.y && b.y <= a.w 
}

rect_grow :: proc{rect_grow_f32, rect_grow_vec2}

rect_grow_vec2 :: #force_inline proc(a: Rect, b: Vec2) -> Rect {
    return {a.x - b.x*0.5, a.y - b.y*0.5, a.z + b.x*0.5, a.w + b.y*0.5}
}

rect_grow_f32 :: #force_inline proc(a: Rect, b: f32) -> Rect {
    center := rect_center(a)
    new_dim := rect_dim(a)*b
    return rect_from_center_dim(center, new_dim)
}

rect_from_pos_dim :: #force_inline proc(a: Vec2, b: Vec2) -> Rect {
    return {a.x, a.y, a.x + b.x, a.y + b.y}
}
