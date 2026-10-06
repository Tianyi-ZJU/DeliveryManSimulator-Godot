shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled;

uniform vec4 fill_color : source_color = vec4(0.13, 0.53, 0.92, 1.0);
uniform vec4 rim_color : source_color = vec4(0.94, 0.96, 0.99, 1.0);

void fragment() {
	// Evaluate the circle at each screen pixel instead of enlarging a raster ring.
	// Derivatives keep both edges smooth even under the oblique map projection.
	vec2 point = UV * 2.0 - 1.0;
	float radius = length(point);
	float edge = max(fwidth(radius), 0.001);
	float coverage = 1.0 - smoothstep(0.92 - edge, 0.92 + edge, radius);
	// UV.y = 0 faces +Y, toward the horizon. Shift the blue center forward:
	// the white rim is thin ahead and broad behind, without a direction glyph.
	float inner_radius = length(point - vec2(0.0, -0.08));
	float inner_edge = max(fwidth(inner_radius), 0.001);
	float rim = smoothstep(0.79 - inner_edge, 0.79 + inner_edge, inner_radius);
	ALBEDO = mix(fill_color.rgb, rim_color.rgb, rim);
	ALPHA = coverage;
}
