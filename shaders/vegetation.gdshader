shader_type spatial;
render_mode cull_disabled;

// Ağaç ve çimen: vertex rengi albedo, vertex rengi alfası rüzgâr sallanma ağırlığı.
// Keşfedilmemiş bölgede hiç çizilmez, keşfedilmiş ama görünmeyende soluk çizilir.
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform float world_size = 1024.0;
uniform float sway = 0.3;

varying float f;
varying vec3 vcol;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	f = texture(fog_tex, wp.xz / world_size).r;
	vcol = COLOR.rgb;
	float w = COLOR.a * sway;
	float t = TIME * 1.7;
	VERTEX.x += sin(t + wp.x * 0.31 + wp.z * 0.17) * 0.16 * w;
	VERTEX.z += cos(t * 0.9 + wp.z * 0.27) * 0.12 * w;
}

void fragment() {
	if (f < 0.14) {
		discard;
	}
	float visible = smoothstep(0.6, 0.9, f);
	vec3 lin = srgb_to_linear(vcol);
	vec3 gray = vec3(dot(lin, vec3(0.30, 0.59, 0.11)));
	vec3 dim = mix(gray, lin, 0.45) * 0.5;
	ALBEDO = mix(dim, lin, visible);
	ROUGHNESS = 1.0;
}
