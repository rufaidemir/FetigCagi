shader_type spatial;
render_mode cull_disabled;

uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform sampler2D wave_normal : filter_linear, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform float world_size = 1024.0;
uniform vec4 shallow_color : source_color = vec4(0.16, 0.62, 0.68, 1.0);
uniform vec4 deep_color : source_color = vec4(0.03, 0.17, 0.36, 1.0);
uniform vec4 sky_color : source_color = vec4(0.55, 0.72, 0.9, 1.0);

varying vec2 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float f = texture(fog_tex, wpos / world_size).r;
	float explored = smoothstep(0.1, 0.4, f);
	float visible = smoothstep(0.6, 0.9, f);

	// Dalgalar: iki katman, farklı yönlere kayan normal haritası
	vec3 a = texture(wave_normal, wpos * 0.06 + vec2(TIME * 0.020, TIME * 0.011)).rgb * 2.0 - 1.0;
	vec3 b = texture(wave_normal, wpos * 0.14 - vec2(TIME * 0.016, -TIME * 0.022)).rgb * 2.0 - 1.0;
	vec3 pn = normalize(vec3((a.x + b.x) * 0.55, 1.0, (a.y + b.y) * 0.55));
	NORMAL = normalize((VIEW_MATRIX * vec4(pn, 0.0)).xyz);

	// Su derinliği: sahne derinliği ile su yüzeyi arasındaki fark
	float depth = texture(depth_tex, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float thickness = max(-view.z + VERTEX.z, 0.0);

	float depth_mix = 1.0 - exp(-thickness * 0.09);
	vec3 col = mix(shallow_color.rgb, deep_color.rgb, depth_mix);

	// Fresnel: eğik bakışta gökyüzü yansıması
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	col = mix(col, sky_color.rgb, fres * 0.55);

	// Kıyı köpüğü
	float foam_noise = texture(wave_normal, wpos * 0.22 + vec2(TIME * 0.03, 0.0)).r;
	float foam = smoothstep(1.8, 0.0, thickness) * (0.55 + foam_noise * 0.6);
	col = mix(col, vec3(0.95, 0.98, 1.0), clamp(foam, 0.0, 1.0));

	float alpha = mix(0.35, 0.94, depth_mix);
	alpha = max(alpha, foam * 0.9);

	vec3 hidden = vec3(0.004, 0.006, 0.012);
	col = mix(hidden, col * 0.5, explored);
	col = mix(col, mix(shallow_color.rgb, col, 1.0), visible);
	ALBEDO = col;
	ALPHA = mix(1.0, alpha, explored);
	ROUGHNESS = 0.06;
	SPECULAR = 0.9;
}
