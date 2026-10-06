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
	# 1. Deep Ambient Stardust (Distant, tiny, ethereal twinkling stars)
	# -------------------------------------------------------------------------
	bg_stardust_particles = CPUParticles3D.new()
	bg_stardust_particles.name = "DeepStardustParticles"
	bg_stardust_particles.local_coords = true
	bg_stardust_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	bg_stardust_particles.emission_box_extents = Vector3(22.0, 26.0, 0.4)
	bg_stardust_particles.amount = 35
	bg_stardust_particles.lifetime = 8.5
	bg_stardust_particles.preprocess = 8.5
	bg_stardust_particles.direction = Vector3(-0.15, -1.0, 0.0)
	bg_stardust_particles.spread = 15.0
	bg_stardust_particles.gravity = Vector3(0.0, -0.25, 0.0)
	bg_stardust_particles.initial_velocity_min = 0.4
	bg_stardust_particles.initial_velocity_max = 1.0
	bg_stardust_particles.angular_velocity_min = -15.0
	bg_stardust_particles.angular_velocity_max = 15.0
	bg_stardust_particles.scale_amount_min = 0.18
	bg_stardust_particles.scale_amount_max = 0.38
	
	# Twinkle Curve
	var deep_curve = Curve.new()
	deep_curve.add_point(Vector2(0.0, 0.0))
	deep_curve.add_point(Vector2(0.18, 0.95))
	deep_curve.add_point(Vector2(0.48, 0.45))
	deep_curve.add_point(Vector2(0.72, 1.0))
	deep_curve.add_point(Vector2(1.0, 0.0))
	bg_stardust_particles.scale_amount_curve = deep_curve
	
	# Color / Alpha Ramp (soft white luminous glow)
	var deep_grad = Gradient.new()
	deep_grad.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.0),
		Color(1.0, 1.0, 1.0, 0.45),
		Color(1.0, 1.0, 1.0, 0.25),
		Color(1.0, 1.0, 1.0, 0.55),
		Color(1.0, 1.0, 1.0, 0.0)
	])
	deep_grad.offsets = PackedFloat32Array([0.0, 0.20, 0.50, 0.80, 1.0])
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
	# 2. Main Falling Stardust Sparkles (Crisp, luminous, twinkling stars)
	# -------------------------------------------------------------------------
	main_stardust_particles = CPUParticles3D.new()
	main_stardust_particles.name = "MainStardustParticles"
	main_stardust_particles.local_coords = true
	main_stardust_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	main_stardust_particles.emission_box_extents = Vector3(22.0, 26.0, 0.4)
	main_stardust_particles.amount = 45
	main_stardust_particles.lifetime = 7.0
	main_stardust_particles.preprocess = 7.0
	main_stardust_particles.direction = Vector3(-0.18, -1.0, 0.0)
	main_stardust_particles.spread = 15.0
	main_stardust_particles.gravity = Vector3(0.0, -0.40, 0.0)
	main_stardust_particles.initial_velocity_min = 0.8
	main_stardust_particles.initial_velocity_max = 1.8
	main_stardust_particles.angular_velocity_min = -25.0
	main_stardust_particles.angular_velocity_max = 25.0
	main_stardust_particles.scale_amount_min = 0.30
	main_stardust_particles.scale_amount_max = 0.68
	
	# Twinkle Scale Curve
	var main_curve = Curve.new()
	main_curve.add_point(Vector2(0.0, 0.1))
	main_curve.add_point(Vector2(0.15, 1.0))
	main_curve.add_point(Vector2(0.38, 0.65))
	main_curve.add_point(Vector2(0.65, 1.15))
	main_curve.add_point(Vector2(0.85, 0.8))
	main_curve.add_point(Vector2(1.0, 0.0))
	main_stardust_particles.scale_amount_curve = main_curve
	
	# Luminous Color Ramp
	var main_grad = Gradient.new()
	main_grad.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.0),
		Color(1.0, 1.0, 1.0, 0.90),
		Color(1.0, 1.0, 1.0, 0.50),
		Color(1.0, 1.0, 1.0, 1.00),
		Color(1.0, 1.0, 1.0, 0.45),
		Color(1.0, 1.0, 1.0, 0.0)
	])
	main_grad.offsets = PackedFloat32Array([0.0, 0.15, 0.38, 0.65, 0.88, 1.0])
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
