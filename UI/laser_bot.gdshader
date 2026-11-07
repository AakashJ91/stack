shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;

uniform sampler2D bot_texture : source_color, filter_linear_mipmap;
uniform vec2 lens_center;
uniform vec2 lens_radius;
uniform vec4 lens_color : source_color = vec4(0.1, 0.85, 1.0, 1.0);
uniform float pulse = 1.0;
uniform vec2 side_light_center;
uniform float side_glow = 1.0;

void vertex() {
	// Keep the sprite facing the camera, with its original size and pixel offset.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]
	);
}

void fragment() {
	vec4 texel = texture(bot_texture, UV);
	vec3 color = texel.rgb;
	float gray = dot(color, vec3(0.2126, 0.7152, 0.0722));
	color = mix(vec3(gray), color, 1.18);
	color = clamp((color - 0.5) * 1.10 + 0.5, vec3(0.0), vec3(1.0));

	vec2 pixel = UV * vec2(textureSize(bot_texture, 0));
	float lens_area = 1.0 - smoothstep(0.75, 1.10, length((pixel - lens_center) / lens_radius));
	float cyan = smoothstep(0.06, 0.35, (texel.g + texel.b) * 0.5 - texel.r);
	float mask = lens_area * cyan;
	color *= mix(0.40, 1.0, cyan);
	color = mix(color, lens_color.rgb * max(texel.g, texel.b) * pulse, mask);
	float side_area = 1.0 - smoothstep(0.75, 1.10, length((pixel - side_light_center) / vec2(28.0, 30.0)));
	float side_mask = side_area * cyan * (1.0 - lens_area);
	color = mix(color, mix(vec3(0.02, 0.035, 0.04), color, side_glow), side_mask);

	ALBEDO = color;
	EMISSION = lens_color.rgb * mask * pulse * 0.18 + vec3(0.05, 0.8, 1.0) * side_mask * side_glow * 0.3;
	// Remove the pale translucent halo while keeping the solid armor and soft edges.
	ALPHA = smoothstep(0.65, 0.98, texel.a);
}
