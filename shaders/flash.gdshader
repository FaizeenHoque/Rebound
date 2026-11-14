shader_type canvas_item;
// Sprite flash (damage / respawn) by mixing towards a solid colour.
// base_tint recolours the sprite itself (black = silhouette) without
// dimming the flash.
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform vec4 base_tint : source_color = vec4(1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(mix(c.rgb * base_tint.rgb, flash_color.rgb, flash), c.a) * COLOR;
}
