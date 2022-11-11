package platform

Layer :: struct {
    data: rawptr,
	on_attach: proc(data: rawptr, app: ^App),
	on_detach: proc(data: rawptr, app: ^App),
	on_update: proc(data: rawptr, app: ^App),
	on_render: proc(data: rawptr, app: ^App),
}
