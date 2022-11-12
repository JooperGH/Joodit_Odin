package platform

import "../events"

Layer :: struct {
    data: rawptr,
	on_attach: proc(data: rawptr, app: ^App),
	on_detach: proc(data: rawptr, app: ^App),
	on_update: proc(data: rawptr, app: ^App),
	on_render: proc(data: rawptr, app: ^App),
	on_event: proc(data: rawptr, e: ^events.Event, app: ^App),
}
