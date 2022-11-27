package main

Vec2 :: [2]f32
Vec3 :: [3]f32
Vec4 :: [4]f32
Mat4 :: [16]f32
Rect :: [4]f32
Color :: [4]f32

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