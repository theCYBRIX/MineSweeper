shader_type canvas_item;

uniform float opacety = 1.0;

void fragment() {
	COLOR = texture(TEXTURE, UV) * vec4(opacety);
}
