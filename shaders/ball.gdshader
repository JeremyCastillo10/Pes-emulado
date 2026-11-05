// Balón con paneles para que se aprecie el giro.
shader_type spatial;
render_mode specular_schlick_ggx;

uniform vec3 base_color : source_color = vec3(0.97, 0.97, 0.97);
uniform vec3 panel_color : source_color = vec3(0.08, 0.10, 0.22);
uniform vec3 accent_color : source_color = vec3(0.9, 0.55, 0.05);

varying vec3 lnorm;

void vertex() {
	lnorm = normalize(VERTEX);
}

void fragment() {
	vec3 n = lnorm;
	// Doce "polos" de un icosaedro aproximado -> paneles
	float best = 0.0;
	vec3 dirs[6] = vec3[](vec3(0.0, 1.0, 1.618), vec3(0.0, -1.0, 1.618), vec3(1.0, 1.618, 0.0),
		vec3(-1.0, 1.618, 0.0), vec3(1.618, 0.0, 1.0), vec3(-1.618, 0.0, 1.0));
	for (int i = 0; i < 6; i++) {
		best = max(best, abs(dot(n, normalize(dirs[i]))));
	}
	float panel = smoothstep(0.93, 0.945, best);
	float ring = smoothstep(0.86, 0.87, best) - smoothstep(0.88, 0.89, best);
	vec3 c = mix(base_color, panel_color, panel);
	c = mix(c, accent_color, ring);
	ALBEDO = c;
	ROUGHNESS = 0.45;
}
