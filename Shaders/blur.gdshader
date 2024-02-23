shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture;

uniform float intensity = 1.0;
uniform int sample_multiplier = 1;
uniform vec2 motion_direction = vec2(1, 0);
uniform float motion_speed = 1.0;

const float BASE_SAMPLE_DISTANCE = 0.001;

vec4 blurred_color(sampler2D source_texture, vec2 uv, float sample_distance){
	vec4 sampled_color;
	vec2 horizontal_offset = vec2(sample_distance, 0);
	vec2 vertical_offset = vec2(0, sample_distance);
	
	sampled_color = texture(source_texture, uv); //center
	
	sampled_color += texture(source_texture, uv - horizontal_offset); //left
	sampled_color += texture(source_texture, uv + horizontal_offset); //right
	sampled_color += texture(source_texture, uv - vertical_offset); //up
	sampled_color += texture(source_texture, uv + vertical_offset); //down
	
	sampled_color += texture(source_texture, uv - sample_distance); //top left
	sampled_color += texture(source_texture, uv + sample_distance); //bottom right
	sampled_color += texture(source_texture, uv + vec2(-sample_distance, sample_distance)); //bottom right
	sampled_color += texture(source_texture, uv + vec2(sample_distance, -sample_distance)); //bottom left
	return sampled_color / 9.0;
}

vec2 offset_uv(vec2 uv){
	return uv + motion_direction * motion_speed * TIME;
}

void fragment() {
	if(intensity > 0.0){
		vec3 sampled_color = vec3(0);
		float distance_unit = (BASE_SAMPLE_DISTANCE * intensity) / float(sample_multiplier);
		for(int i = 1; i <= sample_multiplier; i++){
			sampled_color += blurred_color(TEXTURE, offset_uv(UV), distance_unit * float(i)).rgb;
		}
		COLOR.rgb = sampled_color / float(sample_multiplier);
	} else {
		COLOR.rgb = texture(TEXTURE, offset_uv(UV)).rgb;
	}
}
