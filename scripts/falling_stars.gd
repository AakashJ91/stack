extends Node3D

# Textures
const STARDUST_TEXTURE: Texture2D = preload("res://textures/stardust_sparkle.png")
const STREAK_TEXTURE: Texture2D = preload("res://textures/falling_star_streak.png")

# Particle Emitters
var bg_stardust_particles: CPUParticles3D = null
var main_stardust_particles: CPUParticles3D = null
var _shooting_stars_container: Node3D = null

# Shooting Star Timing
var _shooting_star_timer: float = 0.0
var _next_shooting_star_delay: float = 3.5

func _ready() -> void:
	_setup_background_particles()
	_setup_shooting_stars_container()

func _setup_background_particles() -> void:
	# -------------------------------------------------------------------------
	# 1. Deep Ambient Stardust (Distant, tiny, ethereal twinkling stars)
	# -------------------------------------------------------------------------
	bg_stardust_particles = CPUParticles3D.new()
	bg_stardust_particles.name = "DeepStardustParticles"
	bg_stardust_particles.local_coords = true
	bg_stardust_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	bg_stardust_particles.emission_box_extents = Vector3(36.0, 42.0, 0.4)
	bg_stardust_particles.amount = 38
	bg_stardust_particles.lifetime = 8.5
	bg_stardust_particles.preprocess = 8.5
	bg_stardust_particles.direction = Vector3(-0.12, -1.0, 0.0)
	bg_stardust_particles.spread = 14.0
	bg_stardust_particles.gravity = Vector3(0.0, -0.28, 0.0)
	bg_stardust_particles.initial_velocity_min = 0.5
	bg_stardust_particles.initial_velocity_max = 1.2
	bg_stardust_particles.angular_velocity_min = -15.0
	bg_stardust_particles.angular_velocity_max = 15.0
	bg_stardust_particles.scale_amount_min = 0.20
	bg_stardust_particles.scale_amount_max = 0.42
	
	# Twinkle Curve
	var deep_curve = Curve.new()
	deep_curve.add_point(Vector2(0.0, 0.0))
	deep_curve.add_point(Vector2(0.18, 0.95))
	deep_curve.add_point(Vector2(0.48, 0.45))
	deep_curve.add_point(Vector2(0.72, 1.0))
	deep_curve.add_point(Vector2(1.0, 0.0))
	bg_stardust_particles.scale_amount_curve = deep_curve
	
	# Color / Alpha Ramp
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
	deep_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_NEVER
	deep_mat.albedo_texture = STARDUST_TEXTURE
	deep_mesh.material = deep_mat
	bg_stardust_particles.mesh = deep_mesh
	
	add_child(bg_stardust_particles)
	bg_stardust_particles.position = Vector3(0, 0, -0.4)
	
	# -------------------------------------------------------------------------
	# 2. Main Falling Stardust Sparkles (Crisp, luminous, sparkling stars)
	# -------------------------------------------------------------------------
	main_stardust_particles = CPUParticles3D.new()
	main_stardust_particles.name = "MainStardustParticles"
	main_stardust_particles.local_coords = true
	main_stardust_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	main_stardust_particles.emission_box_extents = Vector3(36.0, 42.0, 0.4)
	main_stardust_particles.amount = 46
	main_stardust_particles.lifetime = 7.0
	main_stardust_particles.preprocess = 7.0
	main_stardust_particles.direction = Vector3(-0.16, -1.0, 0.0)
	main_stardust_particles.spread = 16.0
	main_stardust_particles.gravity = Vector3(0.0, -0.45, 0.0)
	main_stardust_particles.initial_velocity_min = 0.9
	main_stardust_particles.initial_velocity_max = 2.1
	main_stardust_particles.angular_velocity_min = -25.0
	main_stardust_particles.angular_velocity_max = 25.0
	main_stardust_particles.scale_amount_min = 0.32
	main_stardust_particles.scale_amount_max = 0.72
	
	# Twinkle Scale Curve
	var main_curve = Curve.new()
	main_curve.add_point(Vector2(0.0, 0.1))
	main_curve.add_point(Vector2(0.15, 1.0))
	main_curve.add_point(Vector2(0.38, 0.65))
	main_curve.add_point(Vector2(0.65, 1.1))
	main_curve.add_point(Vector2(0.85, 0.8))
	main_curve.add_point(Vector2(1.0, 0.0))
	main_stardust_particles.scale_amount_curve = main_curve
	
	# Luminous Color Ramp
	var main_grad = Gradient.new()
	main_grad.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.0),
		Color(1.0, 1.0, 1.0, 0.85),
		Color(1.0, 1.0, 1.0, 0.50),
		Color(1.0, 1.0, 1.0, 0.95),
		Color(1.0, 1.0, 1.0, 0.40),
		Color(1.0, 1.0, 1.0, 0.0)
	])
	main_grad.offsets = PackedFloat32Array([0.0, 0.15, 0.38, 0.65, 0.88, 1.0])
	main_stardust_particles.color_ramp = main_grad
	
	var main_mesh = QuadMesh.new()
	main_mesh.size = Vector2(0.65, 0.65)
	var main_mat = StandardMaterial3D.new()
	main_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	main_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	main_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	main_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	main_mat.billboard_keep_scale = true
	main_mat.vertex_color_use_as_albedo = true
	main_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_NEVER
	main_mat.albedo_texture = STARDUST_TEXTURE
	main_mesh.material = main_mat
	main_stardust_particles.mesh = main_mesh
	
	add_child(main_stardust_particles)
	main_stardust_particles.position = Vector3(0, 0, 0.0)

func _setup_shooting_stars_container() -> void:
	_shooting_stars_container = Node3D.new()
	_shooting_stars_container.name = "ShootingStarsContainer"
	add_child(_shooting_stars_container)
	_next_shooting_star_delay = randf_range(3.5, 6.5)

func _process(delta: float) -> void:
	_shooting_star_timer += delta
	if _shooting_star_timer >= _next_shooting_star_delay:
		_shooting_star_timer = 0.0
		_next_shooting_star_delay = randf_range(5.0, 8.5)
		_spawn_shooting_star()

func _spawn_shooting_star() -> void:
	if not is_instance_valid(_shooting_stars_container):
		return
	
	# Spawn location near top right / top center in camera space
	var spawn_x = randf_range(2.0, 26.0)
	var spawn_y = randf_range(16.0, 28.0)
	var start_pos = Vector3(spawn_x, spawn_y, 0.2)
	
	# Direction towards down-left with slight angle variance
	var angle_deg = randf_range(-140.0, -155.0)
	var angle_rad = deg_to_rad(angle_deg)
	var dir = Vector3(cos(angle_rad), sin(angle_rad), 0.0).normalized()
	
	var travel_dist = randf_range(34.0, 48.0)
	var end_pos = start_pos + dir * travel_dist
	var duration = randf_range(0.65, 0.95)
	
	# Shooting star root
	var star_root = Node3D.new()
	star_root.position = start_pos
	_shooting_stars_container.add_child(star_root)
	
	# Streak mesh (oriented along travel direction)
	var streak_quad = MeshInstance3D.new()
	var streak_mesh = QuadMesh.new()
	var streak_len = randf_range(3.2, 5.0)
	var streak_thick = randf_range(0.7, 1.1)
	streak_mesh.size = Vector2(streak_len, streak_thick)
	streak_quad.mesh = streak_mesh
	
	var streak_mat = StandardMaterial3D.new()
	streak_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	streak_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	streak_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_NEVER
	streak_mat.albedo_texture = STREAK_TEXTURE
	streak_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
	streak_quad.material_override = streak_mat
	
	# Align head forward: In texture, head is at right (+X).
	# Rotation around Z points +X along dir.
	streak_quad.rotation.z = angle_rad
	# Shift quad slightly backward along dir so the head aligns with star_root center
	streak_quad.position = -dir * (streak_len * 0.45)
	star_root.add_child(streak_quad)
	
	# Head sparkle flare
	var head_sparkle = MeshInstance3D.new()
	var head_mesh = QuadMesh.new()
	var head_size = randf_range(1.1, 1.6)
	head_mesh.size = Vector2(head_size, head_size)
	head_sparkle.mesh = head_mesh
	
	var head_mat = StandardMaterial3D.new()
	head_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	head_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	head_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	head_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_NEVER
	head_mat.albedo_texture = STARDUST_TEXTURE
	head_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
	head_sparkle.material_override = head_mat
	star_root.add_child(head_sparkle)
	
	# Animate shooting star flight with Tween
	var tween = create_tween().set_parallel(true)
	tween.tween_property(star_root, "position", end_pos, duration).set_trans(Tween.TRANS_LINEAR)
	
	# Fade in rapidly, hold, fade out smoothly
	var fade_in_time = duration * 0.22
	var fade_out_time = duration * 0.55
	
	var peak_alpha = randf_range(0.85, 1.0)
	tween.tween_property(streak_mat, "albedo_color:a", peak_alpha, fade_in_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(streak_mat, "albedo_color:a", 0.0, fade_out_time).set_delay(duration - fade_out_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	tween.tween_property(head_mat, "albedo_color:a", peak_alpha, fade_in_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(head_mat, "albedo_color:a", 0.0, fade_out_time).set_delay(duration - fade_out_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Subtle head scale pulse
	tween.tween_property(head_sparkle, "scale", Vector3(1.3, 1.3, 1.3), fade_in_time)
	tween.tween_property(head_sparkle, "scale", Vector3(0.3, 0.3, 0.3), fade_out_time).set_delay(duration - fade_out_time)
	
	tween.chain().tween_callback(star_root.queue_free)
