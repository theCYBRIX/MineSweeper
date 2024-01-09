shader_type canvas_item;

uniform vec2 origin = vec2(0.5, 0.5);
uniform float radius : hint_range(0, 1) = 0.5;
uniform vec4 color : source_color = vec4(0.101961, 0.392157, 1, 1);
uniform float gradiantStart : hint_range(0, 1) = 0.6;
uniform float opacity : hint_range(0, 1) = 1;

void fragment() {
	float dist = distance(UV, origin);
	if(dist <= radius){
		float alpha = 1.0;
		float relativeGradiantStart = gradiantStart * radius;
		if(dist > relativeGradiantStart){
			float fadeFraction = ((radius - dist) / (radius - relativeGradiantStart));
			alpha = color.a * fadeFraction;
		}
		COLOR = mix(COLOR, color, alpha * opacity);
	} 
}
