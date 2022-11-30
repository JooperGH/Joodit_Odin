package main

import "core:log"
import "core:fmt"
import "core:os"
import "core:thread"
import "core:strings"

import stbi "vendor:stb/image"
import gl "vendor:OpenGL"

Texture_Format :: enum {
    Alpha,
    RGB,
    RGBA,
}

Texture :: struct {
    w, h: i32,
    data: []u8,
    format: Texture_Format,
    
    handle: u32,

    load_state: Load_State,
} 

Texture_Load_Task_Data :: struct {
    texture: ^^Texture,
    path: string,
}

texture_load :: proc(texture: ^^Texture, app: ^App, path: string, threaded: bool = true) {
    if !check_load_state(cast(rawptr)texture^, Texture, proc(data: rawptr) {
        texture := cast(^Texture)data
        texture_free(&texture)
    }) {
        return
    }
    
    log.debug("Font load request at ", app_time())
    
    texture^ = new(Texture, context.allocator)
    texture^.load_state = .Queued

    data := new(Texture_Load_Task_Data, context.allocator)
    data.texture = texture
    data.path = path

    if threaded {
        app_push_task(app, texture_load_task, cast(rawptr)data)
    } else {
        ttask := thread.Task{}
        ttask.allocator = context.allocator
        ttask.data = cast(rawptr)data
        ttask.user_index = context.user_index
        texture_load_task(ttask)
    }
}

texture_create :: proc(w, h: i32, format: Texture_Format) -> ^Texture {
    result := new(Texture)
    texture_init(result, w, h, format)
    return result 
}

texture_init :: proc(texture: ^Texture, w, h: i32, format: Texture_Format) {
    texture.w = w
    texture.h = h
    texture.format = format
    bpp := texture_format_to_bpp(format)
    texture.data = make([]u8, w * h * i32(bpp), context.allocator)
    texture.load_state = .Loaded_And_Not_Uploaded
}

texture_free :: proc(texture: ^^Texture) {
    if texture^ != nil {
        delete(texture^.data)
        gl.DeleteTextures(1, cast(^u32)&(texture^).handle)
        texture^.load_state = .Unloaded
        free(texture^)
        texture^ = nil
    }
}

texture_upload :: proc(texture: ^Texture) {
    if !texture_validate_data(texture) {
        log.error("Attempted to upload texture to GPU but data is not valid.")
        return
    }

    handle : u32 = 0
    gl.GenTextures(1, &handle)
    gl.BindTexture(gl.TEXTURE_2D, handle)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)	
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
    
    switch texture.format {
        case .Alpha: gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, texture.w, texture.h, 0, gl.RED, gl.UNSIGNED_BYTE, cast(rawptr)&texture.data[0])
        case .RGB:  gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, texture.w, texture.h, 0, gl.RGB, gl.UNSIGNED_BYTE, cast(rawptr)&texture.data[0])
        case .RGBA: gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, texture.w, texture.h, 0, gl.RGBA, gl.UNSIGNED_BYTE, cast(rawptr)&texture.data[0])
    }

    gl.GenerateMipmap(gl.TEXTURE_2D)
    gl.BindTexture(gl.TEXTURE_2D, 0)

    texture.handle = handle
    texture.load_state = .Loaded_And_Uploaded
}

texture_validate :: proc(texture: ^Texture) -> b32 {
    if texture == nil {
        return false
    }

    if texture.load_state == .Invalid do return false

    if texture.load_state == .Unloaded || texture.load_state == .Queued {
        return false
    }

    if texture.load_state == .Loaded_And_Not_Uploaded {
        texture_upload(texture)
    }

    if texture.load_state == .Loaded_And_Uploaded {
        return true
    }    

    return false
}

@(private)
texture_load_task :: proc(task: thread.Task) {
    task_data := cast(^Texture_Load_Task_Data)task.data
    
    w, h, bpp: i32
    data := stbi.load(strings.clone_to_cstring(task_data.path), &w, &h, &bpp, 0)

    if data != nil {
        texture := task_data.texture^
        texture.data = data[:w*h*bpp]
        texture.w = w
        texture.h = h
        texture.format = texture_format_from_bpp(bpp)
        texture.load_state = .Loaded_And_Not_Uploaded
    } else {
        task_data.texture^.load_state = .Invalid
    }

    free(task_data, context.allocator)
}

@(private)
texture_validate_data :: proc(texture: ^Texture) -> b32 {
    return texture.w != 0 && texture.h != 0 && texture.data != nil
}

@(private)
texture_format_to_bpp :: proc(format: Texture_Format) -> i32 {
    bpp : i32 = 4
    switch format {
        case .Alpha: bpp = 1
        case .RGB: bpp = 3
        case .RGBA: bpp = 4
    }
    return bpp
}

@(private)
texture_format_from_bpp :: proc(bpp: i32) -> Texture_Format {
    format := Texture_Format.Alpha
    switch bpp {
        case 1: format = Texture_Format.Alpha
        case 3: format = Texture_Format.RGB
        case 4: format = Texture_Format.RGBA
    }
    return format
}