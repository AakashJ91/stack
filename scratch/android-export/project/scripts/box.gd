extends Node3D
class_name StackBox

enum BoxState { ATTACHED, FALLING, LANDED, TOPPLING }

var state: BoxState = BoxState.ATTACHED
var box_size: Vector3 = Vector3(2.4, 0.8, 2.4)
var velocity: Vector3 = Vector3.ZERO
var gravity: float = 52.0

# Target landing height (y coordinate of top face of the box below)
var target_landing_y: float = 0.0
var placed_base_pos: Vector3 = Vector3.ZERO

# Hierarchy roots for decoupled animation
# squash_root has origin at bottom face so squashes ground naturally
var squash_root: Node3D
# tilt_root has origin at center of mass so banks and rotates around center
var tilt_root: Node3D

const TEX_DUST_PUFF = preload("res://textures/cloud_puff.png")
const TEX_SURFACE_GRAIN = preload("res://textures/surface_grain.png")

static var _cube_shader: Shader = null

static func _get_cube_shader() -> Shader:
	if _cube_shader == null:
		_cube_shader = Shader.new()
		_cube_shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.48, 0.76, 0.96, 1.0);
uniform vec3 box_half_size = vec3(1.2, 0.4, 1.2);
uniform sampler2D surface_grain : repeat_enable, filter_linear;
uniform sampler2D skin_texture : repeat_enable, filter_linear;
uniform bool skin_use_texture_color = false;
uniform bool skin_wrap_diagonal = false;
uniform bool skin_clear_glass = false;
uniform bool skin_crystal_facets = false;
uniform bool skin_jelly = false;
uniform float skin_texture_strength : hint_range(0.0, 1.0) = 0.0;
uniform float skin_emission_strength : hint_range(0.0, 5.0) = 0.0;
uniform vec2 uv_scale = vec2(0.65, 0.65);
// Matches SurfaceFinish in the block script.
uniform int skin_finish = 0;
uniform float skin_edge_scale = 1.0;
uniform float bevel_width = 0.09;
uniform float chamfer_width = 0.022;
uniform float roughness : hint_range(0.0, 1.0) = 0.32;
uniform float metallic : hint_range(0.0, 1.0) = 0.03;
uniform float reflection_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 emission_color : source_color = vec4(1.0, 0.94, 0.6, 1.0);
uniform float emission_energy : hint_range(0.0, 5.0) = 0.0;

varying vec3 v_local_pos;
varying vec3 v_normal;
varying vec3 v_world_pos;
varying vec3 v_world_normal;
varying vec3 v_view_dir;

void vertex() {
	v_local_pos = VERTEX;
	v_normal = NORMAL;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_view_dir = normalize(CAMERA_POSITION_WORLD - v_world_pos);
}

void fragment() {
	vec3 norm_abs = abs(v_normal);
	vec3 d3 = box_half_size - abs(v_local_pos);
	
	// True 3D metric edge distance on any face orientation
	float edge_dist = 0.0;
	vec2 uv = vec2(0.0);
	if (norm_abs.y > 0.5) {
		edge_dist = min(d3.x, d3.z);
		uv = v_local_pos.xz;
	} else if (norm_abs.x > 0.5) {
		edge_dist = min(d3.y, d3.z);
		uv = v_local_pos.zy;
	} else {
		edge_dist = min(d3.x, d3.y);
		uv = v_local_pos.xy;
	}
	
	// 1. Soft edge ambient occlusion (crisp, readable block layering)
	bool show_edges = skin_edge_scale > 0.0;
	float edge_width = max(skin_edge_scale, 1.0);
	float ao_t = show_edges ? clamp(edge_dist / (bevel_width * edge_width), 0.0, 1.0) : 1.0;
	float ao = mix(0.80, 1.0, ao_t * ao_t * (3.0 - 2.0 * ao_t));
	
	// 2. Beveled chamfer light gleam
	float chamfer_diff = abs(edge_dist - (bevel_width * edge_width * 0.45));
	float chamfer = show_edges ? 1.0 - clamp(chamfer_diff / (chamfer_width * edge_width), 0.0, 1.0) : 0.0;
	chamfer = chamfer * chamfer * 0.14;
	
	// 3. Multi-frequency tactile satin surface grain
	float grain1 = texture(surface_grain, uv * 1.2).r;
	float grain2 = texture(surface_grain, uv * 4.5).r;
	float grain = ((grain1 * 0.65 + grain2 * 0.35) - 0.5) * 0.05;
	
	// 4. Subtle top-face designer inset panel
	float top_inset = 0.0;
	if (show_edges && v_normal.y > 0.5) {
		float d_inset = abs(edge_dist - 0.22);
		float inset_line = 1.0 - clamp(d_inset / 0.018, 0.0, 1.0);
		top_inset = inset_line * inset_line * 0.06;
	}
	
	// 5. Vertical soft volumetric shading
	float vert_shade = (v_local_pos.y / box_half_size.y) * 0.04;
	
	// Mirror-finish suppressions: pristine glass/chrome surfaces have zero dirty grain,
	// clean edge separation instead of muddy ambient occlusion, and diamond-cut specular bevels
	float eff_ao = mix(ao, mix(0.92, 1.0, ao_t), reflection_strength);
	float eff_grain = grain * (1.0 - reflection_strength);
	float eff_inset = top_inset * (1.0 - reflection_strength);
	float eff_vert = vert_shade * (1.0 - reflection_strength * 0.85);
	float mirror_edge_gleam = chamfer * mix(1.0, 5.5, reflection_strength);
	
	// 6. Skin Texture Sampling & Dynamic Blending
	vec3 base_rgb = base_color.rgb;
	float skin_spec = 1.0;
	vec3 skin_emit = vec3(0.0);
	vec3 tex_sheen = vec3(0.0);
	
	if (skin_texture_strength > 0.001) {
		vec2 skin_uv = uv * uv_scale;
		if (skin_wrap_diagonal) {
			// Project through the block so the stripe meets both sides at the same point.
			vec3 p = v_local_pos / box_half_size;
			skin_uv = vec2(0.5 + (p.x + p.z) * 0.85 + (p.y - 1.0) * 0.18, 0.5);
		}
		if (skin_finish == 6) {
			// Four full rows fit the top; the shallow sides use one full row.
			vec2 face_half = norm_abs.y > 0.5 ? box_half_size.xz :
				(norm_abs.x > 0.5 ? box_half_size.zy : box_half_size.xy);
			skin_uv = clamp(uv / (face_half * 2.0) + 0.5, 0.0, 1.0);
			if (norm_abs.y < 0.5) {
				skin_uv.y *= 0.25;
			}
		}
		vec4 skin_tex_val = texture(skin_texture, skin_uv);
		if (reflection_strength > 0.001) {
			// For reflective mirror: texture contributes chromatic sheen streaks & micro-specular gloss
			tex_sheen = (skin_tex_val.rgb - 0.5) * (skin_texture_strength * 0.6);
			skin_spec = mix(1.0, skin_tex_val.a, skin_texture_strength * 0.5);
		} else {
			vec3 tinted_tex = skin_use_texture_color ? skin_tex_val.rgb : base_rgb * skin_tex_val.rgb;
			base_rgb = mix(base_rgb, tinted_tex, skin_texture_strength);
			if (skin_finish == 3) {
				float chip = skin_tex_val.r;
				vec3 stone = mix(base_color.rgb, vec3(0.82), 0.46);
				vec3 aggregate = mix(base_color.rgb * 0.53, mix(base_color.rgb, vec3(1.0), 0.28), step(0.8, chip));
				base_rgb = mix(stone, aggregate, smoothstep(0.15, 0.50, chip));
			} else if (skin_finish == 5) {
				float clay_mask = smoothstep(0.10, 0.22, skin_tex_val.r - skin_tex_val.g);
				vec3 mortar = vec3(dot(skin_tex_val.rgb, vec3(0.299, 0.587, 0.114)));
				vec3 clay = base_color.rgb * mix(0.62, 1.12, skin_tex_val.r);
				base_rgb = mix(mortar, clay, clay_mask);
			} else if (skin_wrap_diagonal) {
				float pale_band = smoothstep(0.72, 0.99, skin_tex_val.r);
				base_rgb = mix(base_color.rgb * 0.83, mix(base_color.rgb, vec3(1.0), 0.45), pale_band);
				float glaze = exp(-abs(fract(skin_uv.x) - 0.71) * 42.0);
				skin_emit += mix(base_color.rgb, vec3(1.0), 0.70) * glaze * 0.10;
			}
			skin_spec = mix(1.0, skin_tex_val.a, skin_texture_strength * 0.35);
			if (skin_emission_strength > 0.001) {
				skin_emit = base_color.rgb * (skin_tex_val.a * skin_emission_strength);
			}
		}
	}
	
	// 7. Dynamic Liquid Mirror & Studio HDR Reflection for Reflective Cube
	vec3 chrome_emission = vec3(0.0);
	if (reflection_strength > 0.001) {
		vec3 norm = normalize(v_world_normal);
		vec3 view = normalize(v_view_dir);
		vec3 refl_dir = reflect(-view, norm);
		
		// 1. Horizon & atmospheric studio environment
		float horizon = smoothstep(-0.22, 0.18, refl_dir.y);
		vec3 sky_zenith = vec3(0.20, 0.35, 0.62);
		vec3 sky_horizon = vec3(0.88, 0.94, 1.0);
		vec3 sky_env = mix(sky_horizon, sky_zenith, clamp(refl_dir.y * 1.3, 0.0, 1.0));
		vec3 ground_env = mix(vec3(0.05, 0.06, 0.09), vec3(0.20, 0.22, 0.28), clamp(-refl_dir.y * 1.5, 0.0, 1.0));
		vec3 env_base = mix(ground_env, sky_env, horizon);
		
		// 2. Razor-sharp chrome horizon stripe (signature liquid metal glint)
		float horiz_glint = exp(-abs(refl_dir.y) * 14.0) * 0.85;
		
		// 3. Multi-source architectural studio softbox reflections
		vec3 s1_dir = normalize(vec3(0.42, 0.78, 0.46));
		float s1_dot = max(dot(refl_dir, s1_dir), 0.0);
		float softbox1 = pow(s1_dot, 16.0) * 1.8 + pow(s1_dot, 72.0) * 3.4;
		
		vec3 s2_dir = normalize(vec3(-0.58, 0.48, -0.66));
		float s2_dot = max(dot(refl_dir, s2_dir), 0.0);
		float softbox2 = pow(s2_dot, 22.0) * 1.3 + pow(s2_dot, 85.0) * 2.5;
		
		vec3 s3_dir = normalize(vec3(0.12, 0.96, -0.22));
		float s3_dot = max(dot(refl_dir, s3_dir), 0.0);
		float softbox3 = pow(s3_dot, 30.0) * 1.4;
		
		vec3 studio_highlights = vec3(1.0, 0.99, 0.97) * (softbox1 + softbox2 + softbox3);
		
		// 4. Subtle dynamic liquid sheen sweep across mirror faces
		float sheen_wave = sin((v_local_pos.x * 0.75 + v_local_pos.z * 0.75 + v_local_pos.y * 1.1) * 3.14159 + (refl_dir.x + refl_dir.z) * 2.8);
		float sheen_band = pow(clamp(sheen_wave * 0.5 + 0.5, 0.0, 1.0), 5.0) * 0.48;
		
		// 5. Chromatic mirror color fusion:
		// Midtones & environment are richly infused with the tower's vibrant pastel palette
		vec3 palette_tint = base_rgb * 1.45 + vec3(0.08);
		vec3 chrome_body = mix(env_base, env_base * palette_tint + base_rgb * 0.28, 0.68);
		
		// Luminous pure silver-white highlights & streaks
		vec3 specular_chrome = studio_highlights + vec3(horiz_glint) + vec3(sheen_band) + tex_sheen;
		vec3 full_mirror_rgb = chrome_body + specular_chrome;
		
		// High specular reflectance across all angles (true mirror F0 ~ 0.85)
		float NdotV = max(dot(norm, view), 0.0);
		float mirror_reflectance = mix(0.85, 1.0, pow(1.0 - NdotV, 3.0));
		base_rgb = mix(base_rgb, full_mirror_rgb, reflection_strength * mirror_reflectance);
		
		// Route luminous chrome highlights and bevel sparkle to emission for bloom
		chrome_emission = (studio_highlights * 0.50 + vec3(horiz_glint * 0.38) + vec3(mirror_edge_gleam * 0.85)) * mix(vec3(1.0), base_color.rgb, 0.35) * reflection_strength;
	}
	
	if (skin_finish == 1) {
		eff_grain *= 0.25;
		eff_inset = 0.0;
		mirror_edge_gleam *= 0.55;
	} else if (skin_finish == 2) {
		vec3 p = v_local_pos / box_half_size;
		float sweep = p.x * 0.44 + p.z * 0.30 + p.y * 0.11;
		float vein_axis = sweep + sin(p.z * 4.2 + p.y * 0.8) * 0.09 + sin(p.x * 9.0 - p.z * 5.0) * 0.021;
		float vein = 1.0 - smoothstep(0.015, 0.053, abs(vein_axis + 0.08));
		float thin_vein = 1.0 - smoothstep(0.006, 0.020, abs(vein_axis - 0.32));
		vec3 stone = mix(base_color.rgb, vec3(0.96), 0.57);
		base_rgb = mix(stone, base_color.rgb * 0.44, max(vein * 0.80, thin_vein * 0.52));
		eff_inset = 0.0;
	} else if (skin_finish == 4) {
		vec3 p = v_local_pos / box_half_size;
		float haze = 0.55 + sin(p.x * 3.5 + p.z * 2.8 + p.y) * 0.12;
		float soft_highlight = exp(-abs(p.x * 0.44 - p.z * 0.48 + p.y * 0.14) * 2.6);
		base_rgb = mix(base_rgb, vec3(0.89, 0.93, 0.97), haze);
		skin_emit += mix(base_color.rgb, vec3(1.0), 0.65) * soft_highlight * 0.12;
		eff_inset = 0.0;
		eff_grain *= 0.20;
	}

	float glass_rim = 0.0;
	if (skin_clear_glass) {
		glass_rim = show_edges ? 1.0 - smoothstep(0.015 * edge_width, 0.14 * edge_width, edge_dist) : 0.0;
		base_rgb = mix(base_rgb * 0.78, mix(base_color.rgb, vec3(1.0), 0.42), glass_rim);
		skin_emit += mix(base_color.rgb, vec3(1.0), 0.40) * glass_rim * 0.30;
		eff_grain = 0.0;
		eff_inset = 0.0;
	}

	if (skin_crystal_facets && v_normal.y > 0.5) {
		vec2 face = uv / box_half_size.xz;
		vec2 facet = abs(face.x) > abs(face.y) ? vec2(sign(face.x), 0.0) : vec2(0.0, sign(face.y));
		float tone = dot(facet, vec2(0.21, 0.12));
		float seam = 1.0 - smoothstep(0.0, 0.025, abs(abs(face.x) - abs(face.y)));
		vec3 facet_normal = normalize(vec3(facet.x * 0.45, 1.0, facet.y * 0.45));
		vec3 face_view = normalize(transpose(mat3(MODEL_MATRIX)) * v_view_dir);
		float flash = pow(max(dot(facet_normal, face_view), 0.0), 10.0);
		vec3 edge_tint = mix(vec3(0.69, 0.83, 1.0), vec3(1.0, 0.77, 0.87), facet.x * 0.5 + 0.5);
		base_rgb = base_color.rgb * (0.82 + tone + flash * 0.38);
		skin_emit += edge_tint * (seam * 0.11 + flash * 0.15);
	}

	if (skin_crystal_facets) {
		base_rgb *= norm_abs.y < 0.5 ? 0.62 : 1.0;
		eff_inset = 0.0;
		eff_grain *= 0.25;
	}

	if (skin_jelly) {
		float inner_glow = smoothstep(0.025, 0.42, edge_dist);
		skin_emit += base_color.rgb * inner_glow * 0.17;
		eff_inset = 0.0;
		eff_grain *= 0.20;
	}

	vec3 col = base_rgb * eff_ao + vec3(mirror_edge_gleam) + vec3(eff_grain) + vec3(eff_inset) + vec3(eff_vert);
	ALBEDO = clamp(col, vec3(0.0), vec3(1.0));
	
	// Keep METALLIC balanced (0.10) so Godot PBR preserves rich diffuse ALBEDO,
	// while keeping ROUGHNESS at pristine 0.012 mirror-finish and maximum SPECULAR
	ROUGHNESS = clamp(mix(mix(roughness * 0.65, roughness * 1.15, 1.0 - ao_t) * skin_spec, 0.012, reflection_strength), 0.01, 0.95);
	METALLIC = clamp(mix(metallic, 0.10, reflection_strength), 0.0, 1.0);
	SPECULAR = mix(0.55, 1.0, reflection_strength);
	
	vec3 total_emission = skin_emit + chrome_emission;
	if (emission_energy > 0.001) {
		total_emission += emission_color.rgb * emission_energy;
	}
	if (length(total_emission) > 0.001) {
		EMISSION = total_emission;
	}
	
	// Transparency / Alpha support
	if (skin_clear_glass) {
		ALPHA = mix(min(base_color.a, 0.34), max(base_color.a * 0.8, 0.90), glass_rim);
	} else if (base_color.a < 0.999) {
		float edge_density = (1.0 - ao_t) * 0.22 + chamfer * 0.45;
		ALPHA = clamp(base_color.a + edge_density, 0.0, 1.0);
	} else {
		ALPHA = 1.0;
	}
}
"""
	return _cube_shader

# Visual instances
var mesh_instance: MeshInstance3D

# Materials
var material: ShaderMaterial
var jelly_landing: bool = false
var dusty_landing: bool = false
enum SurfaceFinish { DEFAULT, SATIN, MARBLE, TERRAZZO, FROSTED, BRICKS, FLORAL }
const SKIN_FINISHES = {
	"classic": SurfaceFinish.SATIN,
	"marble": SurfaceFinish.MARBLE,
	"terrazzo": SurfaceFinish.TERRAZZO,
	"frosted": SurfaceFinish.FROSTED,
	"bricks": SurfaceFinish.BRICKS,
	"floral": SurfaceFinish.FLORAL,
}

# Particle FX
var trail_particles: CPUParticles3D
var drop_particles: CPUParticles3D

# Dynamics
var topple_axis: Vector3 = Vector3.RIGHT
var topple_speed: float = 8.0
var box_color: Color = Color(0.2, 0.6, 0.95)

var settle_tween: Tween = null
var flash_tween: Tween = null
var absorb_tween: Tween = null

signal landed(box: Node3D, hit_target: bool)

func _init() -> void:
	_build_mesh()

func _ready() -> void:
	if not mesh_instance:
		_build_mesh()
	_apply_color()

func _build_mesh() -> void:
	if squash_root:
		return
	
	# Root 1: Squash root anchored at the BOTTOM face of the box
	squash_root = Node3D.new()
	squash_root.name = "SquashRoot"
	squash_root.position = Vector3(0, -box_size.y * 0.5, 0)
	add_child(squash_root)
	
	# Root 2: Tilt root centered at the geometric center of mass
	tilt_root = Node3D.new()
	tilt_root.name = "TiltRoot"
	tilt_root.position = Vector3(0, box_size.y * 0.5, 0)
	squash_root.add_child(tilt_root)
	
	# 1. Main Cube Body with High-Quality Tactile Shading
	mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = box_size
	mesh_instance.mesh = box_mesh
	
	material = ShaderMaterial.new()
	material.shader = _get_cube_shader()
	material.set_shader_parameter("surface_grain", TEX_SURFACE_GRAIN)
	material.set_shader_parameter("box_half_size", box_size * 0.5)
	material.set_shader_parameter("base_color", box_color)
	material.set_shader_parameter("skin_texture", TEX_SURFACE_GRAIN)
	material.set_shader_parameter("skin_texture_strength", 0.0)
	material.set_shader_parameter("skin_emission_strength", 0.0)
	material.set_shader_parameter("uv_scale", Vector2(0.65, 0.65))
	mesh_instance.material_override = material
	tilt_root.add_child(mesh_instance)
	
	# 5. Glider Particle Trail (Emits while sliding)
	trail_particles = CPUParticles3D.new()
	trail_particles.name = "TrailParticles"
	trail_particles.emitting = true
	trail_particles.amount = 18
	trail_particles.lifetime = 0.45
	trail_particles.local_coords = false
	trail_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	trail_particles.emission_box_extents = Vector3(box_size.x * 0.35, 0.15, box_size.z * 0.35)
	trail_particles.gravity = Vector3(0, -1.5, 0)
	trail_particles.initial_velocity_min = 0.2
	trail_particles.initial_velocity_max = 0.8
	trail_particles.scale_amount_min = 0.08
	trail_particles.scale_amount_max = 0.16
	trail_particles.color = box_color.lightened(0.4)
	
	var p_mesh = BoxMesh.new()
	p_mesh.size = Vector3(0.09, 0.09, 0.09)
	var p_mat = StandardMaterial3D.new()
	p_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	p_mat.albedo_color = box_color.lightened(0.4)
	p_mesh.material = p_mat
	trail_particles.mesh = p_mesh
	add_child(trail_particles)
	
	# 6. Drop Speed Sparks (Emits while falling)
	drop_particles = CPUParticles3D.new()
	drop_particles.name = "DropParticles"
	drop_particles.emitting = false
	drop_particles.amount = 16
	drop_particles.lifetime = 0.28
	drop_particles.local_coords = false
	drop_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	drop_particles.emission_box_extents = Vector3(box_size.x * 0.4, 0.1, box_size.z * 0.4)
	drop_particles.gravity = Vector3(0, 8.0, 0)
	drop_particles.initial_velocity_min = 1.0
	drop_particles.initial_velocity_max = 2.5
	drop_particles.scale_amount_min = 0.06
	drop_particles.scale_amount_max = 0.14
	drop_particles.color = box_color.lightened(0.6)
	drop_particles.mesh = p_mesh
	add_child(drop_particles)

func set_color(color: Color) -> void:
	box_color = color
	_apply_color()

func apply_skin(skin_config: Dictionary) -> void:
	if not material:
		return
	var tex = skin_config.get("texture", null)
	var strength = float(skin_config.get("strength", 0.0))
	var emission = float(skin_config.get("emission", 0.0))
	var rough = float(skin_config.get("roughness", 0.32))
	var metal = float(skin_config.get("metallic", 0.03))
	var uv_sc = skin_config.get("uv_scale", Vector2(0.65, 0.65))
	var refl = float(skin_config.get("reflection_strength", 0.0))
	
	if tex:
		material.set_shader_parameter("skin_texture", tex)
	material.set_shader_parameter("skin_texture_strength", strength)
	material.set_shader_parameter("skin_use_texture_color", skin_config.get("use_texture_color", false))
	material.set_shader_parameter("skin_wrap_diagonal", skin_config.get("wrap_diagonal", false))
	var skin_id = skin_config.get("id", "")
	material.set_shader_parameter("skin_finish", SKIN_FINISHES.get(skin_id, SurfaceFinish.DEFAULT))
	dusty_landing = skin_id == "dusty"
	var default_edge_style = 0 if skin_id == "crystal" else 1
	var edge_style = clampi(int(skin_config.get("edge_style", default_edge_style)), 0, 2)
	var edge_scales = [0.0, 1.0, 1.85]
	material.set_shader_parameter("skin_edge_scale", edge_scales[edge_style])
	jelly_landing = skin_id == "jelly"
	material.set_shader_parameter("skin_jelly", jelly_landing)
	material.set_shader_parameter("skin_clear_glass", skin_id == "glass")
	material.set_shader_parameter("skin_crystal_facets", skin_id == "crystal")
	material.set_shader_parameter("skin_emission_strength", emission)
	material.set_shader_parameter("roughness", rough)
	material.set_shader_parameter("metallic", metal)
	material.set_shader_parameter("uv_scale", uv_sc)
	material.set_shader_parameter("reflection_strength", refl)

func _apply_color() -> void:
	if material:
		material.set_shader_parameter("base_color", box_color)
	
	if trail_particles:
		var trail_c = Color.from_hsv(box_color.h, clamp(box_color.s * 0.9, 0.4, 0.7), box_color.v)
		trail_c.a = box_color.a
		trail_particles.color = trail_c
		if trail_particles.mesh and trail_particles.mesh is BoxMesh:
			var pm = (trail_particles.mesh as BoxMesh).material as StandardMaterial3D
			if pm:
				pm.albedo_color = trail_c
	
	if drop_particles:
		var drop_c = Color.from_hsv(box_color.h, clamp(box_color.s * 0.8, 0.35, 0.6), box_color.v)
		drop_c.a = box_color.a
		drop_particles.color = drop_c

# Called continuously while attached to slider
func update_slider_motion(delta: float, velocity_factor: float, axis_index: int, is_aligned: bool, hover_time: float) -> void:
	if state != BoxState.ATTACHED or not is_instance_valid(tilt_root):
		return
	
	# 1. Dynamic Banking / Tilt into direction of motion
	var max_bank_angle = deg_to_rad(6.8)
	if axis_index == 0:
		# Moving along X axis: roll around Z axis
		var target_rot_z = -velocity_factor * max_bank_angle
		tilt_root.rotation.z = lerp(tilt_root.rotation.z, target_rot_z, delta * 14.0)
		tilt_root.rotation.x = lerp(tilt_root.rotation.x, 0.0, delta * 14.0)
	else:
		# Moving along Z axis: pitch around X axis
		var target_rot_x = velocity_factor * max_bank_angle
		tilt_root.rotation.x = lerp(tilt_root.rotation.x, target_rot_x, delta * 14.0)
		tilt_root.rotation.z = lerp(tilt_root.rotation.z, 0.0, delta * 14.0)
	
	# 2. Aerodynamic momentum squash & stretch
	var speed_abs = abs(velocity_factor)
	var stretch_val = 1.0 + (speed_abs * 0.05)
	var compress_val = 1.0 - (speed_abs * 0.025)
	if axis_index == 0:
		squash_root.scale = Vector3(stretch_val, 1.0, compress_val)
	else:
		squash_root.scale = Vector3(compress_val, 1.0, stretch_val)

func drop(initial_velocity: Vector3, landing_y: float) -> void:
	state = BoxState.FALLING
	velocity = initial_velocity
	target_landing_y = landing_y
	
	# Switch particle states
	if is_instance_valid(trail_particles):
		trail_particles.emitting = false
	if is_instance_valid(drop_particles):
		drop_particles.emitting = true
	
	# Cleanly straighten banking rotation as it drops
	if is_instance_valid(tilt_root):
		var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(tilt_root, "rotation", Vector3.ZERO, 0.12)

func _physics_process(delta: float) -> void:
	match state:
		BoxState.FALLING:
			velocity.y -= gravity * delta
			# Add slight air drag on horizontal momentum
			velocity.x = move_toward(velocity.x, 0.0, delta * 2.0)
			velocity.z = move_toward(velocity.z, 0.0, delta * 2.0)
			
			global_position += velocity * delta
			
			# Aerodynamic vertical fall stretch (elongate along Y, compress along X/Z)
			var fall_speed = abs(velocity.y)
			var stretch_y = clamp(1.0 + (fall_speed * 0.01), 1.0, 1.25)
			var squish_xz = 1.0 / sqrt(stretch_y)
			if is_instance_valid(squash_root):
				squash_root.scale = Vector3(squish_xz, stretch_y, squish_xz)
			
			# Check if bottom of this box reaches the target landing height
			var current_bottom_y = global_position.y - (box_size.y * 0.5)
			if current_bottom_y <= target_landing_y:
				# Snap to exact surface level
				global_position.y = target_landing_y + (box_size.y * 0.5)
				landed.emit(self, true)
		
		BoxState.TOPPLING:
			velocity.y -= (gravity * 1.3) * delta
			global_position += velocity * delta
			if is_instance_valid(tilt_root):
				tilt_root.rotate(topple_axis, topple_speed * delta)
			
			# Free when plunged far below
			if global_position.y < -15.0:
				queue_free()

func settle(is_perfect: bool, overhang_ratio: float = 0.0, overhang_dir: Vector3 = Vector3.ZERO) -> void:
	state = BoxState.LANDED
	velocity = Vector3.ZERO
	placed_base_pos = global_position
	if is_instance_valid(tilt_root):
		tilt_root.rotation = Vector3.ZERO
	
	if is_instance_valid(drop_particles):
		drop_particles.emitting = false
	if is_instance_valid(trail_particles):
		trail_particles.emitting = false
	
	# Spawn outward radial particle burst on contact plane
	_spawn_impact_particles(is_perfect)
	
	# Near-miss dramatic edge wobble before stabilizing
	if overhang_ratio > 0.45 and overhang_dir.length_squared() > 0.001 and is_instance_valid(tilt_root):
		var tilt_axis = overhang_dir.cross(Vector3.UP).normalized()
		var wobble_angle = deg_to_rad(5.5 * clamp(overhang_ratio, 0.45, 1.0))
		tilt_root.rotate(tilt_axis, wobble_angle)
		var wobble_tw = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		wobble_tw.tween_property(tilt_root, "rotation", Vector3.ZERO, 0.35)
	
	# Juicy multi-stage elastic squash & stretch spring
	if settle_tween:
		settle_tween.kill()
	settle_tween = create_tween()
	
	var squash_scale = Vector3(1.28, 0.58, 1.28) if not is_perfect else Vector3(1.36, 0.50, 1.36)
	var stretch_scale = Vector3(0.86, 1.20, 0.86) if not is_perfect else Vector3(0.82, 1.28, 0.82)
	var bounce_scale = Vector3(1.05, 0.96, 1.05)
	if jelly_landing:
		squash_scale = Vector3(1.38, 0.48, 1.38)
		stretch_scale = Vector3(0.79, 1.30, 0.79)
		bounce_scale = Vector3(1.12, 0.82, 1.12)
	
	# Stage 1: Fast juicy pancake squash onto surface (anchored at bottom)
	settle_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	settle_tween.tween_property(squash_root, "scale", squash_scale, 0.06)
	
	# Stage 2: Energetic spring rebound stretch
	settle_tween.chain().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	settle_tween.tween_property(squash_root, "scale", stretch_scale, 0.10)
	
	# Stage 3: Second micro-wobble
	settle_tween.chain().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	settle_tween.tween_property(squash_root, "scale", bounce_scale, 0.07)
	
	if jelly_landing:
		settle_tween.chain().tween_property(squash_root, "scale", Vector3(0.96, 1.08, 0.96), 0.07)

	# Stage 4: Settle to rest
	settle_tween.chain().tween_property(squash_root, "scale", Vector3.ONE, 0.06)
	
	if is_perfect:
		_play_perfect_flash()
	else:
		_play_land_flash()

func absorb_impact(depth: int = 1) -> void:
	# Called on previous box(es) when a new box lands on top
	if state != BoxState.LANDED or not is_instance_valid(squash_root):
		return
	if absorb_tween:
		absorb_tween.kill()
	
	# Cascading accordion spring: intensity diminishes down the stack
	var intensity = pow(0.62, float(depth - 1))
	var squash_y = 1.0 - (0.12 * intensity)
	var expand_xz = 1.0 + (0.07 * intensity)
	
	absorb_tween = create_tween()
	absorb_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	absorb_tween.tween_property(squash_root, "scale", Vector3(expand_xz, squash_y, expand_xz), 0.05 + float(depth) * 0.012)
	absorb_tween.chain().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	absorb_tween.tween_property(squash_root, "scale", Vector3.ONE, 0.12)

func flash_sympathetic() -> void:
	# Subtle physical compression pulse down the stack instead of white emission
	if is_instance_valid(squash_root):
		var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(squash_root, "scale", Vector3(1.03, 0.96, 1.03), 0.06)
		tw.chain().tween_property(squash_root, "scale", Vector3.ONE, 0.1)

func start_topple(direction: Vector3) -> void:
	state = BoxState.TOPPLING
	if is_instance_valid(drop_particles):
		drop_particles.emitting = false
	if is_instance_valid(trail_particles):
		trail_particles.emitting = false
	
	topple_axis = direction.cross(Vector3.UP).normalized()
	if topple_axis.length_squared() < 0.001:
		topple_axis = Vector3.RIGHT
	
	velocity = Vector3(direction.x * 2.8, 1.8, direction.z * 2.8)
	topple_speed = 7.5

func _play_land_flash() -> void:
	pass # Keep pastel colors clean and saturated on normal land

func _play_perfect_flash() -> void:
	# Brief golden chime pulse on perfect drop
	if flash_tween:
		flash_tween.kill()
	flash_tween = create_tween().set_parallel(true)
	
	if material:
		material.set_shader_parameter("emission_energy", 1.4)
		flash_tween.tween_method(func(val: float):
			if is_instance_valid(material):
				material.set_shader_parameter("emission_energy", val)
		, 1.4, 0.0, 0.35)

func _spawn_impact_particles(is_perfect: bool) -> void:
	var parent_node = get_parent()
	if not parent_node:
		return
	
	var particles = CPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.96
	particles.amount = 44 if is_perfect else 28
	particles.lifetime = 0.52 if is_perfect else 0.42
	
	# Radial ring burst expanding outward from the contact perimeter
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	particles.emission_ring_axis = Vector3.UP
	particles.emission_ring_height = 0.04
	particles.emission_ring_radius = box_size.x * 0.56
	particles.emission_ring_inner_radius = box_size.x * 0.42
	
	particles.direction = Vector3(0, 0.35, 0)
	particles.spread = 180.0
	particles.initial_velocity_min = 4.2 if is_perfect else 2.8
	particles.initial_velocity_max = 7.0 if is_perfect else 4.6
	particles.gravity = Vector3(0, -6.0, 0)
	particles.damping_min = 2.0
	particles.damping_max = 4.0
	particles.scale_amount_min = 0.08
	particles.scale_amount_max = 0.18
	
	var p_mesh = BoxMesh.new()
	p_mesh.size = Vector3(0.1, 0.1, 0.1)
	var p_mat = StandardMaterial3D.new()
	p_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	
	var h = box_color.h
	var p_col = Color(1.0, 0.94, 0.72) if is_perfect else Color.from_hsv(h, clamp(box_color.s * 0.85, 0.2, 0.45), 1.0)
	p_mat.albedo_color = p_col
	p_mesh.material = p_mat
	particles.mesh = p_mesh
	particles.color = p_col
	
	if dusty_landing:
		var puff = QuadMesh.new()
		puff.size = Vector2(0.65, 0.65)
		p_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		p_mat.albedo_texture = TEX_DUST_PUFF
		p_mat.vertex_color_use_as_albedo = true
		p_mat.albedo_color = Color.WHITE
		puff.material = p_mat
		particles.mesh = puff
		particles.amount = 16
		particles.lifetime = 0.58
		particles.initial_velocity_min = 0.9
		particles.initial_velocity_max = 2.0
		particles.gravity = Vector3(0, 0.25, 0)
		particles.scale_amount_min = 0.65
		particles.scale_amount_max = 1.25
		particles.color = Color(0.86, 0.73, 0.55, 0.58)
		var fade = Gradient.new()
		fade.set_color(0, Color.WHITE)
		fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		particles.color_ramp = fade

	parent_node.add_child(particles)
	particles.global_position = Vector3(global_position.x, target_landing_y + 0.02, global_position.z)
	
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)

func apply_sway_offset(offset: Vector3, tilt_rotation: Vector3) -> void:
	if state == BoxState.LANDED:
		if placed_base_pos == Vector3.ZERO:
			placed_base_pos = global_position
		global_position = placed_base_pos + offset
		if is_instance_valid(tilt_root) and (settle_tween == null or not settle_tween.is_running()):
			tilt_root.rotation = tilt_rotation
