shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled;

// Kameraya dönük can çubuğu. Her çubuk kendi doluluk oranını ve rengini örnek (instance) parametresi olarak taşır.
uniform float bar_scale = 1.0;
instance uniform float ratio = 1.0;
instance uniform float size_mul = 1.0;
instance uniform vec4 fill_color : source_color = vec4(0.3, 0.85, 0.45, 1.0);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	VERTEX *= bar_scale * size_mul;
}

void fragment() {
	float inside = step(UV.x, ratio);
	vec3 col = mix(vec3(0.03, 0.04, 0.08), fill_color.rgb, inside);
	vec2 e = min(UV, vec2(1.0) - UV);
	float border = 1.0 - step(0.08, e.y) * step(0.015, e.x);
	col = mix(col, vec3(0.0), border);
	ALBEDO = col;
	ALPHA = 1.0;
}
