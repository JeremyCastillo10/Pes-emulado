// Red de la portería: malla semitransparente que se deforma con el impacto del balón.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform vec3 net_color : source_color = vec3(0.95);
uniform float cell = 0.12;
uniform vec3 impact_pos = vec3(0.0, -100.0, 0.0);
uniform float impact_age = 10.0;
uniform float impact_strength = 0.0;

varying vec3 wpos;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = distance(wp, impact_pos);
	float falloff = exp(-dist * dist * 0.9);
	float wave = sin(impact_age * 18.0 - dist * 5.0) * exp(-impact_age * 3.0);
	float bulge = exp(-impact_age * 2.2) * 0.55 + wave * 0.12;
	vec3 push = NORMAL * bulge * falloff * impact_strength;
	VERTEX += push;
	wpos = wp;
}

void fragment() {
	vec2 uv = UV / cell;
	vec2 g = abs(fract(uv) - 0.5);
	vec2 fw = fwidth(uv);
	float lw = 0.06;
	float lx = 1.0 - smoothstep(0.5 - lw - fw.x, 0.5 - lw + fw.x, g.x);
	float ly = 1.0 - smoothstep(0.5 - lw - fw.y, 0.5 - lw + fw.y, g.y);
	float a = max(1.0 - lx, 1.0 - ly);
	// En la distancia la red se ve como velo suave
	float far = clamp(max(fw.x, fw.y) * 2.0, 0.0, 1.0);
	// Lejos: tramado (screen-door) para que se vea como un velo fino sin transparencia cara
	float dither = fract(sin(dot(floor(FRAGCOORD.xy), vec2(12.9898, 78.233))) * 43758.5453);
	a = mix(a, step(dither, 0.3), far);
	if (a < 0.5) {
		discard;
	}
	ALBEDO = net_color;
	ROUGHNESS = 0.9;
}
