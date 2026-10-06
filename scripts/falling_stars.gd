extends Node3D

# Textures
const STARDUST_TEXTURE: Texture2D = preload("res://textures/stardust_sparkle.png")

# Particle Emitters
var bg_stardust_particles: CPUParticles3D = null
var main_stardust_particles: CPUParticles3D = null

func _ready() -> void:
	_setup_background_particles()

func _setup_background_particles() -> void:
	# -------------------------------------------------------------------------
	# 1. Deep Ambient Stardust (Distant, tiny, soft shimmering stars)
	# -------------------------------------------------------------------------
	bg_stardust_particles = CPUParticles3D.new()
	bg_stardust_particles.name = "DeepStardustParticles"
	bg_stardust_particles.local_coords = true
	bg_stardust_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	bg_stardust_particles.emission_box_extents = Vector3(22.0, 26.0, 0.4)
	bg_stardust_particles.amount = 40
	bg_stardust_particles.lifetime = 15.0
	bg_stardust_particles.preprocess = 15.0
	bg_stardust_particles.direction = Vector3(-0.08, -1.0, 0.0)
	bg_stardust_particles.spread = 18.0
	bg_stardust_particles.gravity = Vector3(0.0, -0.04, 0.0)
	bg_stardust_particles.initial_velocity_min = 0.15
	bg_stardust_particles.initial_velocity_max = 0.38
	bg_stardust_particles.angular_velocity_min = -18.0
	bg_stardust_particles.angular_velocity_max = 18.0
	bg_stardust_particles.scale_amount_min = 0.16
	bg_stardust_particles.scale_amount_max = 0.36
	
	# Multi-peak Twinkle Scale Curve (subtle pulsing)
	var deep_curve = Curve.new()
	deep_curve.add_point(Vector2(0.00, 0.00))
	deep_curve.add_point(Vector2(0.08, 0.85))
	deep_curve.add_point(Vector2(0.18, 0.30))
	deep_curve.add_point(Vector2(0.30, 0.95))
	deep_curve.add_point(Vector2(0.42, 0.35))
	deep_curve.add_point(Vector2(0.55, 1.00))
	deep_curve.add_point(Vector2(0.68, 0.30))
	deep_curve.add_point(Vector2(0.80, 0.90))
	deep_curve.add_point(Vector2(0.90, 0.35))
	deep_curve.add_point(Vector2(1.00, 0.00))
	bg_stardust_particles.scale_amount_curve = deep_curve
	
	# Multi-peak Alpha Ramp
	var deep_grad = Gradient.new()
	deep_grad.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.00),
		Color(1.0, 1.0, 1.0, 0.55),
		Color(1.0, 1.0, 1.0, 0.18),
		Color(1.0, 1.0, 1.0, 0.65),
		Color(1.0, 1.0, 1.0, 0.22),
		Color(1.0, 1.0, 1.0, 0.70),
		Color(1.0, 1.0, 1.0, 0.18),
		Color(1.0, 1.0, 1.0, 0.60),
		Color(1.0, 1.0, 1.0, 0.20),
		Color(1.0, 1.0, 1.0, 0.00)
	])
	deep_grad.offsets = PackedFloat32Array([
		0.00, 0.08, 0.18, 0.30, 0.42, 0.55, 0.68, 0.80, 0.90, 1.00
	])
	bg_stardust_particles.color_ramp = deep_grad
	
	var deep_mesh = QuadMesh.new()
	deep_mesh.size = Vector2(0.45, 0.45)
	var deep_mat = StandardMaterial3D.new()
	deep_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	deep_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	deep_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	deep_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	deep_mat.billboard_keep_scale = true
	deep_mat.vertex_color_use_as_albedo = true
	deep_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	deep_mat.albedo_texture = STARDUST_TEXTURE
	deep_mesh.material = deep_mat
	bg_stardust_particles.mesh = deep_mesh
	
	add_child(bg_stardust_particles)
	bg_stardust_particles.position = Vector3(0, 0, -0.4)
	
	# -------------------------------------------------------------------------
	# 2. Main Falling Stardust Sparkles (Crisp, slow drift, lively twinkling)
	# -------------------------------------------------------------------------
	main_stardust_particles = CPUParticles3D.new()
	main_stardust_particles.name = "MainStardustParticles"
	main_stardust_particles.local_coords = true
	main_stardust_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	main_stardust_particles.emission_box_extents = Vector3(22.0, 26.0, 0.4)
	main_stardust_particles.amount = 55
	main_stardust_particles.lifetime = 13.0
	main_stardust_particles.preprocess = 13.0
	main_stardust_particles.direction = Vector3(-0.10, -1.0, 0.0)
	main_stardust_particles.spread = 20.0
	main_stardust_particles.gravity = Vector3(0.0, -0.06, 0.0)
	main_stardust_particles.initial_velocity_min = 0.22
	main_stardust_particles.initial_velocity_max = 0.52
	main_stardust_particles.angular_velocity_min = -28.0
	main_stardust_particles.angular_velocity_max = 28.0
	main_stardust_particles.scale_amount_min = 0.28
	main_stardust_particles.scale_amount_max = 0.65
	
	# Multi-peak Twinkle Scale Curve (distinct sparkling flashes)
	var main_curve = Curve.new()
	main_curve.add_point(Vector2(0.00, 0.00))
	main_curve.add_point(Vector2(0.07, 1.05))
	main_curve.add_point(Vector2(0.16, 0.35))
	main_curve.add_point(Vector2(0.26, 1.20))
	main_curve.add_point(Vector2(0.38, 0.40))
	main_curve.add_point(Vector2(0.50, 1.25))
	main_curve.add_point(Vector2(0.63, 0.35))
	main_curve.add_point(Vector2(0.75, 1.15))
	main_curve.add_point(Vector2(0.86, 0.45))
	main_curve.add_point(Vector2(0.95, 0.90))
	main_curve.add_point(Vector2(1.00, 0.00))
	main_stardust_particles.scale_amount_curve = main_curve
	
	# Multi-peak Luminous Twinkle Ramp (rhythmic sparkling peaks)
	var main_grad = Gradient.new()
	main_grad.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.00),
		Color(1.0, 1.0, 1.0, 0.95),
		Color(1.0, 1.0, 1.0, 0.30),
		Color(1.0, 1.0, 1.0, 1.00),
		Color(1.0, 1.0, 1.0, 0.35),
		Color(1.0, 1.0, 1.0, 1.00),
		Color(1.0, 1.0, 1.0, 0.28),
		Color(1.0, 1.0, 1.0, 0.95),
		Color(1.0, 1.0, 1.0, 0.35),
		Color(1.0, 1.0, 1.0, 0.85),
		Color(1.0, 1.0, 1.0, 0.00)
	])
	main_grad.offsets = PackedFloat32Array([
		0.00, 0.07, 0.16, 0.26, 0.38, 0.50, 0.63, 0.75, 0.86, 0.95, 1.00
	])
	main_stardust_particles.color_ramp = main_grad
	
	var main_mesh = QuadMesh.new()
	main_mesh.size = Vector2(0.60, 0.60)
	var main_mat = StandardMaterial3D.new()
	main_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	main_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	main_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	main_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	main_mat.billboard_keep_scale = true
	main_mat.vertex_color_use_as_albedo = true
	main_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	main_mat.albedo_texture = STARDUST_TEXTURE
	main_mesh.material = main_mat
	main_stardust_particles.mesh = main_mesh
	
	add_child(main_stardust_particles)
	main_stardust_particles.position = Vector3(0, 0, 0.0)
