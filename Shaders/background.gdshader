shader_type canvas_item;

uniform sampler2D sampler : repeat_enable, filter_linear_mipmap;

uniform vec2 direction = vec2(1.0, 0.0);
uniform float speed_scale = 0.1;
uniform int blur_sample_step_size = 1;

void fragment() {
	vec2 move = direction * TIME * speed_scale;
	vec2 sample_position = UV + move;
	vec3 color = texture(sampler, sample_position).xyz;
	COLOR.xyz = color;
}