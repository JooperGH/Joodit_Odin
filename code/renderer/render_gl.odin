package renderer

GPU_Handle :: distinct u32

gl_renderer := Batch_Renderer{}

Batch_Renderer :: struct {
	vertex_array: u32,
	vertex_buffer: u32,


}

init :: proc() {
    gl_renderer.vertex_array = 0
    gl_renderer.vertex_buffer = 0
}