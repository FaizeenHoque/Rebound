shader_type canvas_item;
// Pixel-dither wipe used between scenes.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fill_color : source_color = vec4(0.0627, 0.0941, 0.1529, 1.0);

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int m[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return float(m[y * 4 + x]) / 16.0;
}

void fragment() {
	vec2 cell = floor(FRAGCOORD.xy / 2.0);
	float sweep = progress * 1.6 - UV.x * 0.6;
	float a = step(bayer4(cell) + 0.03, sweep);
	vec3 c = fill_color.rgb;
	// glowing edge on the wipe front
	if (a > 0.5 && step(bayer4(cell) + 0.15, sweep) < 0.5) {
		c = vec3(0.133, 0.827, 0.933) * 0.6;
	}
	COLOR = vec4(c, a);
}
