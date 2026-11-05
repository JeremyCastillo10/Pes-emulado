// Césped procedural: franjas/patrones de corte, desgaste en áreas y líneas nítidas
// (antialias con fwidth, nítidas a cualquier resolución y sin texturas).
shader_type spatial;
render_mode cull_back, specular_schlick_ggx;

uniform vec3 grass_light : source_color = vec3(0.19, 0.38, 0.13);
uniform vec3 grass_dark : source_color = vec3(0.14, 0.29, 0.10);
uniform vec3 dirt_color : source_color = vec3(0.42, 0.34, 0.22);
uniform vec3 line_color : source_color = vec3(0.96, 0.97, 0.95);
uniform int pattern = 0;            // 0 franjas, 1 cuadros, 2 círculos, 3 diagonal, 4 franjas finas
uniform float stripe_width = 5.25;
uniform float wear : hint_range(0.0, 1.0) = 0.55;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform float line_half_width = 0.06;
uniform vec2 half_size = vec2(52.5, 34.0);

varying vec3 wpos;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float sd_box(vec2 p, vec2 b) {
	vec2 d = abs(p) - b;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// Distancia a la línea más cercana del campo.
float lines_dist(vec2 p) {
	float d = abs(sd_box(p, half_size));          // bandas y líneas de meta
	d = min(d, abs(p.x));                          // línea central
	d = min(d, abs(length(p) - 9.15));             // círculo central
	d = min(d, max(length(p) - 0.15, 0.0));        // punto central
	float s = sign(p.x + 0.0001);
	vec2 q = vec2(abs(p.x), p.y);
	float gx = half_size.x;
	// Área grande y área chica
	d = min(d, abs(sd_box(q - vec2(gx - 8.25, 0.0), vec2(8.25, 20.16))));
	d = min(d, abs(sd_box(q - vec2(gx - 2.75, 0.0), vec2(2.75, 9.16))));
	// Punto penal y semicírculo
	vec2 spot = vec2(gx - 11.0, 0.0);
	d = min(d, max(length(q - spot) - 0.15, 0.0));
	float arc = abs(length(q - spot) - 9.15);
	if (q.x < gx - 16.5) {
		d = min(d, arc);
	}
	// Arcos de esquina
	vec2 c = vec2(gx, half_size.y);
	vec2 qc = vec2(abs(p.x), abs(p.y));
	if (qc.x < gx && qc.y < half_size.y) {
		d = min(d, abs(length(qc - c) - 1.0));
	}
	return d;
}

float mow_pattern(vec2 p) {
	vec2 o = p + half_size;
	if (pattern == 1) {
		float a = mod(floor(o.x / stripe_width), 2.0);
		float b = mod(floor(o.y / stripe_width), 2.0);
		return abs(a - b);
	} else if (pattern == 2) {
		return mod(floor(length(p) / (stripe_width * 0.9)), 2.0);
	} else if (pattern == 3) {
		return mod(floor((o.x + o.y) / (stripe_width * 1.2)), 2.0);
	} else if (pattern == 4) {
		return mod(floor(o.x / (stripe_width * 0.5)), 2.0);
	}
	return mod(floor(o.x / stripe_width), 2.0);
}

float wear_amount(vec2 p) {
	vec2 q = vec2(abs(p.x), p.y);
	float gx = half_size.x;
	float w = 0.0;
	// Boca de gol y área chica (zona del portero)
	w = max(w, exp(-(pow((q.x - (gx - 2.0)) / 3.2, 2.0) + pow(q.y / 4.5, 2.0))));
	// Punto penal
	w = max(w, 0.7 * exp(-(pow((q.x - (gx - 11.0)) / 2.0, 2.0) + pow(q.y / 2.0, 2.0))));
	// Círculo central
	w = max(w, 0.45 * exp(-dot(p, p) / 16.0));
	// Bandas (líneas de juez de línea)
	w = max(w, 0.35 * exp(-pow((abs(p.y) - half_size.y - 1.5) / 0.8, 2.0)) * step(abs(p.x), gx));
	return w;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float stripe = mow_pattern(p);
	float n = vnoise(p * 0.35) * 0.6 + vnoise(p * 2.7) * 0.3 + hash(floor(p * 18.0)) * 0.1;
	vec3 grass = mix(grass_dark, grass_light, stripe);
	grass *= 0.88 + n * 0.22;

	float w = wear_amount(p) * wear;
	float wn = vnoise(p * 1.6) * 0.8 + vnoise(p * 6.0) * 0.4;
	float worn = smoothstep(0.35, 0.9, w * (0.6 + wn));
	vec3 col = mix(grass, dirt_color * (0.85 + wn * 0.2), worn);

	float d = lines_dist(p);
	float fw = max(fwidth(d), 0.0005);
	float line = 1.0 - smoothstep(line_half_width - fw, line_half_width + fw, d);
	// Las líneas lejanas se atenúan un poco para evitar parpadeo
	line *= clamp(line_half_width * 2.5 / fw, 0.35, 1.0);
	col = mix(col, line_color * (0.92 + n * 0.08), line * (1.0 - worn * 0.4));

	// Césped mojado: más oscuro y brillante
	col *= 1.0 - wetness * 0.22;
	ALBEDO = col;
	ROUGHNESS = mix(0.92, 0.38, wetness);
	SPECULAR = mix(0.25, 0.6, wetness);
}
