shader_type canvas_item;

uniform int samples_per_layer = 4;
uniform float intensity = 1;

const int SAMPLE_LAYERS = 2;
const vec2 OFFSET_UNIT = vec2(0.001, 0.001);

uniform vec2 motion = vec2(1, 0);
uniform float speed = 1.0;

uniform vec3 blend_color : source_color = vec3(0);
uniform float blend_fraction : hint_range(0.0, 1.0) = 0.0;

uniform float darken : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 offset_uv = UV + motion * speed * TIME;
	
	vec4 sampled_color = vec4(0);
	vec2 offset = OFFSET_UNIT * intensity;
	vec2[] offsets = { offset / 2.0, offset };
	int total_samples = samples_per_layer * SAMPLE_LAYERS;
	float angle_offset = (2.0 * PI) / float(total_samples);
	float angle = 0.0;
	for(int i = 0; i < total_samples; i++){
		vec2 sample_dist = offsets[i % SAMPLE_LAYERS];
		sampled_color += texture(TEXTURE, offset_uv + vec2(cos(angle) * sample_dist.x, sin(angle) * sample_dist.y));
		angle += angle_offset;
	}
	COLOR.rgb = mix(mix((sampled_color / float(total_samples)).rgb, blend_color, blend_fraction), vec3(0), darken).rgb;
}
