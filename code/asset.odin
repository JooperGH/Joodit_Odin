package main

import "core:log"

Load_State :: enum {
    Invalid,
    Unloaded,
    Queued,
    Loaded_And_Not_Uploaded,
    Loaded_And_Uploaded,
}

check_load_state :: proc(data: rawptr, $T: typeid, invalid_proc: proc(data: rawptr)) -> b32 {
    asset := cast(^T)data

    if asset == nil {
        return true
    }

    switch asset.load_state {
        case .Invalid:
            invalid_proc(data)
            return true
        case .Unloaded:
            return true
        case .Queued: 
            log.debug("Asset load request received while asset is already queued for load.")
            return false
        case .Loaded_And_Not_Uploaded, .Loaded_And_Uploaded: 
            log.debug("Tried to load asset but it is already loaded.")
            return false
    }

    return true
}