shader_type canvas_item;

uniform int samples_per_layer = 4;
uniform float intensity = 1;

uniform int sample_layers = 2;
const float OFFSET_UNIT = 0.001;

uniform vec2 motion = vec2(1, 0);
uniform float speed = 1.0;

uniform vec3 blend_color : source_color = vec3(0);
uniform float blend_fraction : hint_range(0.0, 1.0) = 0.0;

uniform float darken : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 offset_uv = UV + motion * speed * TIME;
	
	vec4 sampled_color = texture(TEXTURE, offset_uv);
	float offset = OFFSET_UNIT * intensity;
	float layer_width = offset / float(sample_layers);
	float angle_offset = (2.0 * PI) / float(samples_per_layer);
	float angle = 0.0;
	for(int layer = 1; layer <= sample_layers; layer++){
		float sample_distance = layer_width * float(layer);
		for(int i = 0; i < samples_per_layer; i++){
			sampled_color += texture(TEXTURE, offset_uv + vec2(cos(angle) * sample_distance, sin(angle) * sample_distance));
			angle += angle_offset;
		}
	}
	sampled_color /= float(sample_layers * samples_per_layer + 1);
	COLOR.rgb = mix(mix(sampled_color.rgb, blend_color, blend_fraction), vec3(0), darken).rgb;
}
