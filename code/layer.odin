package main

Layer :: struct {
    data: rawptr,
	on_attach: proc(rawptr, ^App),
	on_detach: proc(rawptr, ^App),
	on_update: proc(rawptr, ^App),
	on_render: proc(rawptr, ^App),
	on_event: proc(rawptr, ^App, ^Event),
}
