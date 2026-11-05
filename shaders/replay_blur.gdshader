// Desenfoque leve en los bordes y viñeta para las repeticiones.
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 1.6;

void fragment() {
	vec2 c = SCREEN_UV - 0.5;
	float d = length(c * vec2(1.6, 1.0));
	float lod = smoothstep(0.25, 0.75, d) * strength;
	vec3 col = textureLod(screen_tex, SCREEN_UV, lod).rgb;
	col *= 1.0 - smoothstep(0.45, 0.95, d) * 0.45;
	// Ligero tono cálido de "cámara lenta"
	col = mix(col, col * vec3(1.05, 1.0, 0.92), 0.5);
	COLOR = vec4(col, 1.0);
}
