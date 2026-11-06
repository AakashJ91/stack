shader_type canvas_item;
render_mode unshaded;

uniform vec2 surface_size = vec2(1.0);

void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	vec2 edge = min(uv, 1.0 - uv) * surface_size;
	float edge_distance = min(edge.x, edge.y);

	// Keep the reflection near the top on both the dock and tall drawers.
	float depth = uv.y * surface_size.y;
	float reflection = exp(-depth / 23.0) * mix(0.25, 0.09, uv.x);
	float rim = (1.0 - smoothstep(0.5, 3.0, edge_distance)) * exp(-depth / 16.0) * 0.42;
	float sheen = min(reflection + rim, 1.0);
	COLOR = vec4(COLOR.rgb, sheen * COLOR.a);
}
