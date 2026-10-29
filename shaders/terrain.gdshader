shader_type spatial;
render_mode cull_disabled;

// Keşif sisi: 0 = bilinmeyen (kapkaranlık), 0.5 = keşfedilmiş (soluk), 1 = görünür.
uniform sampler2D fog_tex : filter_linear, repeat_disable;
// Gürültü dokuları: renk çeşitliliği ve yüzey kabartması için.
uniform sampler2D detail_tex : filter_linear, repeat_enable;
uniform sampler2D detail_normal : filter_linear, repeat_enable;
uniform float world_size = 1024.0;

varying vec2 wpos;
varying vec3 vcol;
varying vec3 wn;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	vcol = COLOR.rgb;
	wn = NORMAL;
}

void fragment() {
	float f = texture(fog_tex, wpos / world_size).r;
	float explored = smoothstep(0.1, 0.4, f);
	float visible = smoothstep(0.6, 0.9, f);

	vec3 lin = srgb_to_linear(vcol);

	// Büyük ve ince ölçekli renk değişimi (yamalı çimen, toprak)
	float macro = texture(detail_tex, wpos * 0.011).r;
	float mid = texture(detail_tex, wpos * 0.09).r;
	float fine = texture(detail_tex, wpos * 0.45).r;
	lin *= 0.80 + macro * 0.40;
	lin *= 0.90 + fine * 0.18 + (mid - 0.5) * 0.14;

	// Dik yüzeyler kayaya döner (kar ve deniz tabanı hariç)
	float lum = dot(vcol, vec3(0.3333));
	float slope = 1.0 - clamp(wn.y, 0.0, 1.0);
	float rock = smoothstep(0.28, 0.5, slope) * (1.0 - smoothstep(0.80, 0.92, lum));
	vec3 rock_col = srgb_to_linear(vec3(0.43, 0.41, 0.39)) * (0.7 + fine * 0.6);
	lin = mix(lin, rock_col, rock * 0.85);

	// Yüzey kabartması: gürültü normal haritasını dünya uzayında ekle
	vec3 n1 = texture(detail_normal, wpos * 0.35).rgb * 2.0 - 1.0;
	vec3 n2 = texture(detail_normal, wpos * 0.09).rgb * 2.0 - 1.0;
	vec3 pn = normalize(wn + vec3(n1.x * 0.30 + n2.x * 0.22, 0.0, n1.y * 0.30 + n2.y * 0.22));
	NORMAL = normalize((VIEW_MATRIX * vec4(pn, 0.0)).xyz);

	vec3 gray = vec3(dot(lin, vec3(0.30, 0.59, 0.11)));
	vec3 dim = mix(gray, lin, 0.45) * 0.5;
	vec3 col = mix(vec3(0.004, 0.006, 0.012), dim, explored);
	col = mix(col, lin, visible);
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
