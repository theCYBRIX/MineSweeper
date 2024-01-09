shader_type canvas_item;

void fragment() {
	vec3 color = texture(TEXTURE, UV).xyz * 0.16;
	color += texture(TEXTURE, UV + vec2(0.0, 2.0 * SCREEN_PIXEL_SIZE.y)).xyz * 0.15;
	color += texture(TEXTURE, UV + vec2(0.0, 2.0 * -SCREEN_PIXEL_SIZE.y)).xyz * 0.15;
	color += texture(TEXTURE, UV + vec2(0.0, 4.0 * SCREEN_PIXEL_SIZE.y)).xyz * 0.12;
	color += texture(TEXTURE, UV + vec2(0.0, 4.0 * -SCREEN_PIXEL_SIZE.y)).xyz * 0.12;
	color += texture(TEXTURE, UV + vec2(0.0, 8.0 * SCREEN_PIXEL_SIZE.y)).xyz * 0.09;
	color += texture(TEXTURE, UV + vec2(0.0, 8.0 * -SCREEN_PIXEL_SIZE.y)).xyz * 0.09;
	color += texture(TEXTURE, UV + vec2(0.0, 10.0 * SCREEN_PIXEL_SIZE.y)).xyz * 0.05;
	color += texture(TEXTURE, UV + vec2(0.0, 10.0 * -SCREEN_PIXEL_SIZE.y)).xyz * 0.05;
	COLOR.xyz = color;
}
