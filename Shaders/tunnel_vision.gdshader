shader_type canvas_item;

uniform float radius : hint_range(0.0, 0.5) = 0.25;
uniform vec2 center = vec2(0.5, 0.5);
uniform vec4 borderColor : source_color = vec4(0, 0, 0, 1);
uniform float fade : hint_range(0.0, 1.0) = 0.15;

void fragment() {
	float distFromCenter = distance(UV, center);
	float distFromRadius = distance(radius, distFromCenter);
	float relativeFade = radius * fade;
	
	if(distFromRadius < relativeFade){
		float fadeStart = radius - relativeFade;
		COLOR = mix(texture(TEXTURE, UV), borderColor, (distFromCenter - fadeStart) / relativeFade);
	} else if(distFromCenter > radius){
		COLOR = borderColor;
	} else {
		COLOR = texture(TEXTURE, UV);
	}
}
