package rect_pack

import "core:mem"
import "core:sort"
import "core:log"

Rect :: struct {
    x, y: i32,
    w, h: i32,

    user_data: rawptr,
    data: []byte,
}

Context :: struct {
    allocator: mem.Allocator,
    packing: b32,
    w, h: i32,
    rects: [dynamic]Rect,
}

begin :: proc(rpc: ^Context, allocator: mem.Allocator = context.allocator) {
    assert(rpc.packing == false)
    rpc.allocator = allocator
    rpc.packing = true
    rpc.w = 256
    rpc.h = 256
    rpc.rects = make([dynamic]Rect, 0, 100,allocator)
}

push :: proc(rpc: ^Context, w, h: i32, user_data: rawptr, data: []byte) {
    append(&rpc.rects, Rect{0, 0, w, h, user_data, data})
}

@private
try_pack :: proc(rpc: ^Context, first_run : b32 = true) -> b32 {
    if rpc.w > 2048 || rpc.h > 2048 {
        return false
    }

    if first_run {
        sort.quick_sort_proc(rpc.rects[:], proc(a: Rect, b: Rect) -> int {
            return a.w < b.w ? 0 : 1
        })
    }

    success : b32 = true
    x, y, mh : i32 = 0, 0, 0
    for r in &rpc.rects {
        if x + r.w > rpc.w {
            if mh == 0 {
                success = false
                break
            }

            y += mh
            x = 0
            mh = 0
        }

        if y + r.h > rpc.h {
            success = false
            break
        }

        r.x = x
        r.y = y

        x += r.w
        
        if r.h > mh {
            mh = r.h
        }
    }

    if !success {
        if rpc.w > rpc.h {
            rpc.h *= 2
        } else if rpc.w == rpc.h {
            rpc.w *= 2
        }

        success = try_pack(rpc, false)
    }

    return success
}

end :: proc(rpc: ^Context) -> b32 {
    assert(rpc.packing == true)

    if !try_pack(rpc) {
        log.debug("Failed to pack up to 2048x2048 region.")
        return false
    }   

    rpc.packing = false

    return true
}

free :: proc(rpc: ^Context) {
    rpc.w = 0
    rpc.h = 0
    delete(rpc.rects)
}