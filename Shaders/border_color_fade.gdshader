shader_type canvas_item;

uniform float borderSize : hint_range(0.0, 0.5) = 0.25;
uniform vec3 borderColor : source_color = vec3(0, 0, 0);
uniform float fade : hint_range(0.0, 1.0) = 0.15;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 textureColor = texture(TEXTURE, UV);
	float farBorder = 1.0 - borderSize;
	float relativeFade = borderSize * (1.0 - fade);
	float opacityOffset = 1.0 - opacity;
	vec4 adjustedColor = mix(vec4(borderColor, 1.0), textureColor, opacityOffset);
	
	if(UV.r < borderSize){
		float mixFraction;
		
		if(UV.g < borderSize){
			vec2 curveCenter = vec2(borderSize);
			mixFraction = distance(UV, curveCenter) / (borderSize - relativeFade);
		} else if(UV.g > farBorder){
			vec2 curveCenter = vec2(borderSize, farBorder);
			mixFraction = distance(UV, curveCenter) / (borderSize - relativeFade);
		} else {
			mixFraction = (borderSize - UV.r) / (borderSize - relativeFade);
		}
		COLOR = mix(texture(TEXTURE, UV), adjustedColor, min(mixFraction, 1));
		
	} else if(UV.r > farBorder){
		float mixFraction;
		
		if(UV.g < borderSize){
			vec2 curveCenter = vec2(farBorder, borderSize);
			mixFraction = distance(UV, curveCenter) / (borderSize - relativeFade);
		} else if(UV.g > farBorder){
			vec2 curveCenter = vec2(farBorder);
			mixFraction = distance(UV, curveCenter) / (borderSize - relativeFade);
		} else {
			mixFraction = (UV.r - farBorder) / (borderSize - relativeFade);
		}
		COLOR = mix(texture(TEXTURE, UV), adjustedColor, min(mixFraction, 1));
	
	} else if(UV.g < borderSize){
		float mixFraction = (borderSize - UV.g) / (borderSize - relativeFade);
		COLOR = mix(texture(TEXTURE, UV), adjustedColor, min(mixFraction, 1));
		
	} else if(UV.g > farBorder){
		float mixFraction = (UV.g - farBorder) / (borderSize - relativeFade);
		COLOR = mix(texture(TEXTURE, UV), adjustedColor, min(mixFraction, 1));
		
	} else {
		COLOR = texture(TEXTURE, UV);
	}
}
