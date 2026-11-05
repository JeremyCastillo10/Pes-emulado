// Público: un quad por espectador (MultiMesh). Silueta procedural, color por
// instancia y animación que depende del nivel de emoción.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert, specular_disabled;

uniform float excitement : hint_range(0.0, 1.0) = 0.15;
uniform float lod_fade = 1.0;

varying vec3 shirt;
varying float phase;

void vertex() {
	shirt = COLOR.rgb;
	phase = INSTANCE_CUSTOM.x * 6.2831;
	float jump = max(sin(TIME * (4.0 + INSTANCE_CUSTOM.y * 3.0) + phase), 0.0);
	float idle = sin(TIME * 1.3 + phase) * 0.02;
	VERTEX.y += idle + jump * 0.28 * excitement * step(0.35, INSTANCE_CUSTOM.z + excitement * 0.6);
	// Brazos arriba con emoción: estirar la parte superior
	VERTEX.x += sin(TIME * 2.0 + phase) * 0.03 * excitement * UV.y;
}

void fragment() {
	vec2 uv = vec2(UV.x - 0.5, 1.0 - UV.y);
	// Cabeza
	float head = step(length(uv - vec2(0.0, 0.82)) , 0.14);
	// Torso (trapecio)
	float body = step(abs(uv.x), 0.30 - uv.y * 0.05) * step(uv.y, 0.68) * step(0.0, uv.y);
	float m = max(head, body);
	if (m < 0.5) {
		discard;
	}
	vec3 skin = vec3(0.85, 0.66, 0.5) * (0.6 + fract(phase * 3.1) * 0.5);
	vec3 c = mix(shirt, skin, head);
	c *= 0.75 + uv.y * 0.35;
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
