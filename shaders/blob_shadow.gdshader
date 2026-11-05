// Sombra circular barata bajo jugadores y balón (útil en calidad Baja sin sombras dinámicas).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float strength = 0.45;

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	ALBEDO = vec3(0.0);
	ALPHA = (1.0 - smoothstep(0.3, 1.0, d)) * strength;
}
