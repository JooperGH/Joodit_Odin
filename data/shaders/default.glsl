#vertex

#version 330

layout (location = 0) in vec2 a_pos_vec;
layout (location = 1) in vec2 a_tc;
layout (location = 2) in vec4 a_color;
layout (location = 3) in vec4 a_border_color;
layout (location = 4) in float a_tex_id;
layout (location = 5) in float a_mode;
layout (location = 6) in vec4 a_rect;
layout (location = 7) in vec4 a_rect_params;

out vec2 f_tc;
out float f_tex_id;

flat out vec4 f_color;
flat out vec2 a_pos_vec;  
flat out vec4 f_border_color;
flat out vec4 f_rect_params;
flat out vec2 f_center;
flat out float f_mode;
flat out vec2 f_half_dim;

uniform mat4 u_proj;

void main() {
    f_tc = a_tc;
    f_color = a_color;
    f_border_color = a_border_color;
    f_tex_id = a_tex_id;
    f_mode = a_mode;
    f_rect_params = a_rect_params;
    f_half_dim = 0.5*(a_rect.zw - a_rect.xy);
    f_center = a_rect.xy + f_half_dim;
    vec2 pos = f_center + f_half_dim*a_pos_vec;
    gl_Position = u_proj * vec4(pos, 0.0, 1.0);
}

#fragment

#version 330

in vec2 f_tc;

in vec4 f_color;
in vec4 f_border_color;
in float f_tex_id;
in float f_mode;
in vec2 f_center;
in vec2 f_half_dim;
in vec4 f_rect_params;

layout(origin_upper_left) in vec4 gl_FragCoord;

out vec4 o_color;

uniform sampler2D u_textures[32];

float rounded_rect_sdf(vec2 sample_pos, vec2 center, vec2 half_dim, float r) {
    vec2 d2 = (abs(center - sample_pos) - half_dim + vec2(r, r));
    return min(max(d2.x, d2.y), 0.0) + length(max(d2, 0.0)) - r;
}

vec2 rounded_rect_factor(float radius, float softness, float border_thickness, vec2 pos, vec2 center, vec2 half_dim) {
    vec2 softness_padding = vec2(max(0.0, softness*2.0-1.0), max(0.0, softness*2.0-1.0));
    float dist = rounded_rect_sdf(pos, center, half_dim-softness_padding, radius);
    float sdf_factor = 1.0 - smoothstep(0.0, 2.0*softness, dist);

    float border_factor = 0.0;
    if (border_thickness != 0.0) {
        vec2 interior_half_size = half_dim - vec2(border_thickness, border_thickness);
        float interior_radius_reduce_f = min(interior_half_size.x/half_dim.x, interior_half_size.y/half_dim.y);
        float interior_corner_radius = (radius * interior_radius_reduce_f * interior_radius_reduce_f);

        float inside_d = rounded_rect_sdf(pos, center, interior_half_size-softness_padding, interior_corner_radius);

        border_factor = smoothstep(0, 2.0*softness, inside_d);
    }

    return vec2(sdf_factor, border_factor);
}

void main() {
    switch (int(f_mode)) {
        case 0: {
            float radius = f_rect_params.x;
            float softness = f_rect_params.y;
            float border_thickness = f_rect_params.z;
            vec2 factors = rounded_rect_factor(radius, softness, border_thickness, gl_FragCoord.xy, f_center, f_half_dim);
            o_color = mix(f_color, f_border_color, factors.y) * factors.x;
        } break;
        case 1: {
            float radius = f_rect_params.x;
            float softness = f_rect_params.y;
            float border_thickness = f_rect_params.z;
            vec2 factors = rounded_rect_factor(radius, softness, border_thickness, gl_FragCoord.xy, f_center, f_half_dim);
            o_color = mix(f_color * texture(u_textures[int(f_tex_id)], f_tc), f_border_color, factors.y) * factors.x;
        } break;
        case 2: {
            float alpha = texture(u_textures[int(f_tex_id)], f_tc).r;
            o_color = vec4(f_color.rgb, alpha);
        } break;
    }
}