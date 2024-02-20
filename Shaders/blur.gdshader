shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture;

uniform float intensity = 1.0;
uniform vec2 motion_direction = vec2(1, 0);
uniform float motion_speed = 1.0;

const vec2 BASE_SAMPLE_DISTANCE = vec2(0.001, 0.001);

vec4 blurred_color(sampler2D source_texture, vec2 uv){
	vec4 sampled_color;
	vec2 sample_distance = BASE_SAMPLE_DISTANCE * intensity;
	vec2 horizontal_offset = vec2(sample_distance.x, 0);
	vec2 vertical_offset = vec2(0, sample_distance.y);
	sampled_color = texture(source_texture, uv - horizontal_offset); //left
	sampled_color += texture(source_texture, uv + horizontal_offset); //right
	sampled_color += texture(source_texture, uv - vertical_offset); //up
	sampled_color += texture(source_texture, uv + vertical_offset); //down
	
	sampled_color += texture(source_texture, uv - sample_distance); //top left
	sampled_color += texture(source_texture, uv + sample_distance); //bottom right
	sampled_color += texture(source_texture, uv + vec2(-sample_distance.x, sample_distance.y)); //bottom right
	sampled_color += texture(source_texture, uv + vec2(sample_distance.x, -sample_distance.y)); //bottom left
	return sampled_color / 8.0;
}

void fragment() {
	COLOR.rgb = blurred_color(TEXTURE, UV + motion_direction * motion_speed * TIME).rgb;
}
