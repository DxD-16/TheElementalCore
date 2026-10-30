shader_type canvas_item;

uniform vec4 ice_tint : source_color = vec4(0.55, 0.82, 1.0, 1.0);
uniform float frost_amount : hint_range(0.0, 1.0) = 0.75;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV) * COLOR;
	float frost = smoothstep(0.15, 0.9, UV.y + sin(UV.x * 42.0) * 0.04);
	vec3 frozen_color = mix(tex_color.rgb, ice_tint.rgb, frost_amount * (0.65 + frost * 0.35));
	COLOR = vec4(frozen_color, tex_color.a);
}
