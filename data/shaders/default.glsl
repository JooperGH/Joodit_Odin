#vertex

#version 330

layout (location = 0) in vec2 a_pos;
layout (location = 1) in vec2 a_tc;
layout (location = 2) in vec4 a_color;
layout (location = 3) in float a_tex_id;
layout (location = 4) in float a_mode;

out vec2 f_tc;
out vec4 f_color;
out float f_tex_id;
out float f_mode;

uniform mat4 u_proj;

void main() {
    gl_Position = u_proj * vec4(a_pos, 0.0, 1.0);
    f_tc = a_tc;
    f_color = a_color;
    f_tex_id = a_tex_id;
    f_mode = a_mode;
}

#fragment

#version 330

in vec2 f_tc;
in vec4 f_color;
in float f_tex_id;
in float f_mode;

out vec4 o_color;

uniform sampler2D u_textures[32];

const float edge = 0.7;
const float smoothness = 0.05;

void main() {
    switch (int(f_mode)) {
        case 0: {
            o_color = f_color;
        } break;
        case 1: {
            o_color = texture(u_textures[int(f_tex_id)], f_tc) * f_color;
        } break;
        case 2: {
            float dist = texture(u_textures[int(f_tex_id)], f_tc).r;
            float alpha = smoothstep(edge-smoothness, edge+smoothness, dist);
            o_color = vec4(f_color.rgb, alpha) * f_color.a;
        } break;
        case 3: {
            float alpha = texture(u_textures[int(f_tex_id)], f_tc).r;
            o_color = vec4(f_color.rgb, alpha);
        } break;
    }
}