extends Node3D

const StackBox = preload("res://scripts/box.gd")
const CubeSlider = preload("res://scripts/cube_slider.gd")

enum GameState { READY, PLAYING, DROPPING, GAME_OVER }

var state: GameState = GameState.READY
var score: int = 0
var high_score: int = 0
var combo: int = 0
var best_combo: int = 0

const BOX_SIZE: Vector3 = Vector3(2.4, 0.8, 2.4)
const PERFECT_THRESHOLD: float = 0.22
const MAX_OVERHANG_DISTANCE: float = 1.15

var stack: Array[Node3D] = []
var base_pedestal: MeshInstance3D
var current_top_y: float = 0.0
var current_target_pos: Vector3 = Vector3.ZERO

# Camera tracking
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
var target_camera_y: float = 0.0
var base_camera_pivot_y: float = 0.0
var screen_shake_trauma: float = 0.0

# Nodes
@onready var slider: Node3D = $Slider
@onready var sound_mgr = $SoundEffects
@onready var ui_layer = $UI
@onready var score_label = $UI/HUD/ScoreLabel
@onready var combo_label = $UI/HUD/ComboLabel
@onready var prompt_label = $UI/HUD/PromptLabel
@onready var game_over_panel = $UI/GameOverPanel
@onready var final_score_label = $UI/GameOverPanel/VBox/FinalScore
@onready var best_score_label = $UI/GameOverPanel/VBox/BestScore
@onready var new_best_badge = $UI/GameOverPanel/VBox/NewBestBadge
@onready var sound_btn = $UI/HUD/SoundBtn

var active_box: Node3D = null

var pedestal_rim: MeshInstance3D

# Gradient Background Components
var bg_quad: MeshInstance3D
var bg_gradient: Gradient
var bg_texture: GradientTexture2D
var bg_material: StandardMaterial3D
var bg_tween: Tween = null

# Celestial & Dynamic Background Elements
var bg_star_particles: CPUParticles3D
var bg_mote_particles: CPUParticles3D
var bg_hero_stars: Array[Dictionary] = []
var bg_star_texture: ImageTexture
var bg_bokeh_texture: GradientTexture2D
var shooting_star_timer: float = 2.5
var next_shooting_star_delay: float = 4.5
var bg_anim_time: float = 0.0

# Curated high-aesthetic pastel color palettes for stacking runs
# Each palette has its own dedicated complementary atmospheric gradient background
const PALETTES: Array[Dictionary] = [
	{
		"name": "Pastel Rainbow Spectrum",
		"mode": "rainbow",
		"speed": 0.026,
		"sat": 0.54,
		"val": 0.92,
		"bg_top": Color(0.08, 0.09, 0.18),    # Deep Twilight Navy
		"bg_bottom": Color(0.20, 0.14, 0.28) # Soft Twilight Violet
	},
	{
		"name": "Cotton Candy",
		"mode": "gradient",
		"colors": [
			Color(0.95, 0.52, 0.68), # Pastel Rose Pink
			Color(0.78, 0.58, 0.92), # Pastel Lilac
			Color(0.58, 0.65, 0.96), # Pastel Periwinkle
			Color(0.48, 0.76, 0.96), # Pastel Sky Blue
			Color(0.45, 0.88, 0.74), # Pastel Mint Seafoam
			Color(0.96, 0.84, 0.45)  # Pastel Buttercup
		],
		"bg_top": Color(0.12, 0.09, 0.22),    # Deep Heather Mauve
		"bg_bottom": Color(0.24, 0.12, 0.22) # Soft Dusty Rose
	},
	{
		"name": "Peach Sorbet",
		"mode": "gradient",
		"colors": [
			Color(0.98, 0.62, 0.48), # Pastel Peach
			Color(0.98, 0.75, 0.48), # Pastel Apricot
			Color(0.96, 0.86, 0.45), # Pastel Vanilla Cream
			Color(0.96, 0.58, 0.68), # Pastel Strawberry
			Color(0.82, 0.62, 0.88)  # Pastel Wisteria
		],
		"bg_top": Color(0.15, 0.10, 0.17),    # Deep Cocoa Slate
		"bg_bottom": Color(0.26, 0.15, 0.18) # Warm Sunset Mauve
	},
	{
		"name": "Mint & Sage Serenity",
		"mode": "gradient",
		"colors": [
			Color(0.45, 0.88, 0.72), # Pastel Mint
			Color(0.52, 0.88, 0.84), # Pastel Seafoam
			Color(0.48, 0.78, 0.94), # Pastel Powder Blue
			Color(0.75, 0.65, 0.92), # Pastel Soft Lilac
			Color(0.95, 0.82, 0.50)  # Pastel Primrose
		],
		"bg_top": Color(0.07, 0.12, 0.16),    # Deep Nordic Spruce
		"bg_bottom": Color(0.11, 0.20, 0.21) # Soft Deep Seafoam
	},
	{
		"name": "Nordic Rose & Ice",
		"mode": "gradient",
		"colors": [
			Color(0.92, 0.58, 0.68), # Pastel Dusk Rose
			Color(0.78, 0.62, 0.85), # Pastel Heather
			Color(0.52, 0.75, 0.92), # Pastel Ice Blue
			Color(0.48, 0.84, 0.78), # Pastel Sage Teal
			Color(0.92, 0.78, 0.58)  # Pastel Sand Amber
		],
		"bg_top": Color(0.09, 0.12, 0.20),    # Deep Arctic Slate
		"bg_bottom": Color(0.17, 0.14, 0.25) # Soft Nordic Lilac
	}
]
var palette_index: int = 0
var current_palette_start_hue: float = 0.58

func _ready() -> void:
	_setup_desktop_window_size()
	get_tree().root.size_changed.connect(_on_window_resized)
	_on_window_resized()

	load_high_score()
	_setup_lighting_and_env()
	_setup_gradient_background()
	_create_pedestal()
	base_camera_pivot_y = camera_pivot.position.y
	target_camera_y = base_camera_pivot_y
	
	slider.box_released.connect(_on_box_released)
	sound_btn.pressed.connect(_on_sound_btn_pressed)
	$UI/GameOverPanel/VBox/RestartBtn.pressed.connect(restart_game)
	
	reset_game()

func _setup_gradient_background() -> void:
	bg_quad = MeshInstance3D.new()
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(90.0, 90.0)
	bg_quad.mesh = quad_mesh
	bg_quad.position = Vector3(0, 0, -45.0)
	bg_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	bg_gradient = Gradient.new()
	var pal = PALETTES[palette_index % PALETTES.size()]
	var top_c = pal.get("bg_top", Color(0.08, 0.09, 0.18)) as Color
	var bot_c = pal.get("bg_bottom", Color(0.20, 0.14, 0.28)) as Color
	bg_gradient.colors = PackedColorArray([top_c, bot_c])
	bg_gradient.offsets = PackedFloat32Array([0.0, 1.0])
	
	bg_texture = GradientTexture2D.new()
	bg_texture.gradient = bg_gradient
	bg_texture.fill_from = Vector2(0.3, 0.0) # Elegant diagonal top-left
	bg_texture.fill_to = Vector2(0.7, 1.0)   # to bottom-right
	bg_texture.width = 64
	bg_texture.height = 128
	
	bg_material = StandardMaterial3D.new()
	bg_material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	bg_material.albedo_texture = bg_texture
	bg_quad.material_override = bg_material
	
	camera.add_child(bg_quad)
	
	# Generate celestial textures
	bg_star_texture = _create_star_texture()
	bg_bokeh_texture = _create_bokeh_texture()
	
	# Setup starfield, floating stardust motes, and hero twinkling stars
	_setup_starfield_particles()
	_setup_mote_particles()
	_setup_hero_stars()

func _create_star_texture() -> ImageTexture:
	var size = 64
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size * 0.5, size * 0.5)
	var radius = size * 0.48
	
	for y in range(size):
		for x in range(size):
			var pos = Vector2(x + 0.5, y + 0.5)
			var offset = pos - center
			var dist = offset.length()
			var nx = abs(offset.x) / radius
			var ny = abs(offset.y) / radius
			
			var core = exp(-dist * 0.28)
			var ray_x = max(0.0, 1.0 - nx) * exp(-abs(offset.y) * 0.75)
			var ray_y = max(0.0, 1.0 - ny) * exp(-abs(offset.x) * 0.75)
			var diag1 = max(0.0, 1.0 - (nx + ny) * 0.9) * 0.35
			
			var intensity = clamp(core * 0.65 + (ray_x + ray_y) * 0.75 + diag1, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, intensity))
	
	return ImageTexture.create_from_image(img)

func _create_bokeh_texture() -> GradientTexture2D:
	var tex = GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var g = Gradient.new()
	g.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.95),
		Color(1.0, 1.0, 1.0, 0.35),
		Color(1.0, 1.0, 1.0, 0.0)
	])
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	tex.gradient = g
	tex.width = 64
	tex.height = 64
	return tex

func _setup_starfield_particles() -> void:
	bg_star_particles = CPUParticles3D.new()
	bg_star_particles.amount = 75
	bg_star_particles.lifetime = 4.5
	bg_star_particles.preprocess = 4.5
	bg_star_particles.speed_scale = 0.85
	bg_star_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	bg_star_particles.emission_box_extents = Vector3(22.0, 16.0, 0.5)
	bg_star_particles.position = Vector3(0, 0, -42.0)
	bg_star_particles.gravity = Vector3.ZERO
	bg_star_particles.direction = Vector3(0.2, 0.1, 0)
	bg_star_particles.spread = 180.0
	bg_star_particles.initial_velocity_min = 0.02
	bg_star_particles.initial_velocity_max = 0.08
	
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.0))
	scale_curve.add_point(Vector2(0.25, 1.0))
	scale_curve.add_point(Vector2(0.5, 0.35))
	scale_curve.add_point(Vector2(0.75, 0.95))
	scale_curve.add_point(Vector2(1.0, 0.0))
	bg_star_particles.scale_amount_curve = scale_curve
	bg_star_particles.scale_amount_min = 0.12
	bg_star_particles.scale_amount_max = 0.36
	
	var quad = QuadMesh.new()
	quad.size = Vector2(0.7, 0.7)
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = bg_star_texture
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	bg_star_particles.mesh = quad
	bg_star_particles.color = Color(0.95, 0.96, 1.0, 0.85)
	
	camera.add_child(bg_star_particles)

func _setup_mote_particles() -> void:
	bg_mote_particles = CPUParticles3D.new()
	bg_mote_particles.amount = 30
	bg_mote_particles.lifetime = 6.5
	bg_mote_particles.preprocess = 6.0
	bg_mote_particles.speed_scale = 0.85
	bg_mote_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	bg_mote_particles.emission_box_extents = Vector3(20.0, 15.0, 0.5)
	bg_mote_particles.position = Vector3(0, 0, -41.0)
	bg_mote_particles.gravity = Vector3(0, 0.25, 0)
	bg_mote_particles.direction = Vector3(0.1, 1.0, 0)
	bg_mote_particles.spread = 45.0
	bg_mote_particles.initial_velocity_min = 0.12
	bg_mote_particles.initial_velocity_max = 0.38
	
	var mote_curve = Curve.new()
	mote_curve.add_point(Vector2(0.0, 0.0))
	mote_curve.add_point(Vector2(0.2, 0.85))
	mote_curve.add_point(Vector2(0.8, 0.85))
	mote_curve.add_point(Vector2(1.0, 0.0))
	bg_mote_particles.scale_amount_curve = mote_curve
	bg_mote_particles.scale_amount_min = 0.22
	bg_mote_particles.scale_amount_max = 0.60
	
	var quad = QuadMesh.new()
	quad.size = Vector2(0.85, 0.85)
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = bg_bokeh_texture
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	bg_mote_particles.mesh = quad
	bg_mote_particles.color = Color(0.88, 0.92, 1.0, 0.45)
	
	camera.add_child(bg_mote_particles)

func _setup_hero_stars() -> void:
	for item in bg_hero_stars:
		if is_instance_valid(item.get("mesh")):
			(item["mesh"] as Node).queue_free()
	bg_hero_stars.clear()
	
	var star_positions = [
		Vector3(-7.2, 5.8, -40.5),
		Vector3(6.5, 6.2, -40.5),
		Vector3(-8.5, -1.8, -40.5),
		Vector3(7.8, -3.5, -40.5),
		Vector3(1.2, 6.8, -40.5),
		Vector3(-4.5, -6.0, -40.5),
		Vector3(5.2, 1.5, -40.5),
		Vector3(-2.8, 3.8, -40.5)
	]
	
	for i in range(star_positions.size()):
		var pos = star_positions[i]
		var star_mesh_inst = MeshInstance3D.new()
		var qm = QuadMesh.new()
		var base_scale = randf_range(0.45, 0.85)
		qm.size = Vector2(base_scale, base_scale)
		star_mesh_inst.mesh = qm
		star_mesh_inst.position = pos
		star_mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		
		var mat = StandardMaterial3D.new()
		mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_texture = bg_star_texture
		mat.albedo_color = Color(1.0, 0.98, 0.92, randf_range(0.65, 0.95))
		star_mesh_inst.material_override = mat
		
		camera.add_child(star_mesh_inst)
		
		bg_hero_stars.append({
			"mesh": star_mesh_inst,
			"mat": mat,
			"pos": pos,
			"base_scale": base_scale,
			"rot_speed": randf_range(-0.35, 0.35),
			"pulse_speed": randf_range(1.2, 2.5),
			"phase": randf_range(0.0, TAU)
		})

func _spawn_shooting_star() -> void:
	if not is_instance_valid(camera) or not bg_star_texture:
		return
	
	var from_left = randf() > 0.5
	var start_x = randf_range(-14.0, -9.0) if from_left else randf_range(9.0, 14.0)
	var end_x = randf_range(6.0, 12.0) if from_left else randf_range(-12.0, -6.0)
	var start_y = randf_range(5.5, 9.5)
	var end_y = start_y - randf_range(4.5, 7.0)
	
	var start_pos = Vector3(start_x, start_y, -40.2)
	var end_pos = Vector3(end_x, end_y, -40.2)
	
	var star_root = Node3D.new()
	star_root.position = start_pos
	camera.add_child(star_root)
	
	var head = MeshInstance3D.new()
	var head_mesh = QuadMesh.new()
	head_mesh.size = Vector2(0.6, 0.6)
	var head_mat = StandardMaterial3D.new()
	head_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	head_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	head_mat.albedo_texture = bg_star_texture
	head_mat.albedo_color = Color(1.0, 0.98, 0.90, 1.0)
	head.mesh = head_mesh
	head.material_override = head_mat
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	star_root.add_child(head)
	
	var trail = CPUParticles3D.new()
	trail.emitting = true
	trail.amount = 24
	trail.lifetime = 0.38
	trail.speed_scale = 1.0
	trail.local_coords = false
	trail.gravity = Vector3.ZERO
	trail.initial_velocity_min = 0.1
	trail.initial_velocity_max = 0.5
	trail.spread = 180.0
	trail.scale_amount_min = 0.1
	trail.scale_amount_max = 0.28
	trail.color = Color(1.0, 0.96, 0.88, 0.85)
	
	var trail_mesh = BoxMesh.new()
	trail_mesh.size = Vector3(0.06, 0.06, 0.06)
	var trail_mat = StandardMaterial3D.new()
	trail_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	trail_mesh.material = trail_mat
	trail.mesh = trail_mesh
	star_root.add_child(trail)
	
	var duration = randf_range(0.6, 0.8)
	var tween = star_root.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(star_root, "position", end_pos, duration)
	tween.tween_property(head_mat, "albedo_color:a", 0.0, duration * 0.4).set_delay(duration * 0.6)
	tween.chain().tween_callback(func():
		if is_instance_valid(trail):
			trail.emitting = false
		get_tree().create_timer(0.4).timeout.connect(func():
			if is_instance_valid(star_root):
				star_root.queue_free()
		)
	)

func _spawn_cosmic_background_ripple() -> void:
	if not is_instance_valid(camera) or not bg_star_texture:
		return
	var ripple = CPUParticles3D.new()
	ripple.emitting = true
	ripple.one_shot = true
	ripple.explosiveness = 0.92
	ripple.amount = 22
	ripple.lifetime = 0.9
	ripple.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	ripple.emission_ring_radius = 0.8
	ripple.emission_ring_inner_radius = 0.4
	ripple.emission_ring_axis = Vector3.BACK
	ripple.position = Vector3(0, 0, -40.3)
	ripple.direction = Vector3.UP
	ripple.spread = 180.0
	ripple.initial_velocity_min = 2.5
	ripple.initial_velocity_max = 5.0
	ripple.gravity = Vector3.ZERO
	ripple.scale_amount_min = 0.16
	ripple.scale_amount_max = 0.38
	
	var box_c = _get_box_shade(stack.size())
	ripple.color = box_c.lerp(Color.WHITE, 0.55)
	
	var quad = QuadMesh.new()
	quad.size = Vector2(0.65, 0.65)
	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = bg_star_texture
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = mat
	ripple.mesh = quad
	
	camera.add_child(ripple)
	get_tree().create_timer(1.1).timeout.connect(func():
		if is_instance_valid(ripple):
			ripple.queue_free()
	)

# Floating 3D/Screen score popups
func _spawn_floating_score_popup(world_pos: Vector3, text: String, color: Color, is_special: bool) -> void:
	if not is_instance_valid(camera):
		return
	var screen_pos = camera.unproject_position(world_pos + Vector3(0, 0.6, 0))
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var font_size = 38 if is_special else 26
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	
	label.size = Vector2(260, 60)
	label.pivot_offset = Vector2(130, 30)
	label.position = screen_pos - Vector2(130, 30)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	ui_layer.add_child(label)
	
	var tw = label.create_tween().set_parallel(true)
	label.scale = Vector2(1.4, 1.4) if is_special else Vector2(1.15, 1.15)
	tw.tween_property(label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "position:y", label.position.y - (50.0 if is_special else 34.0), 0.50).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.20).set_delay(0.32)
	tw.chain().tween_callback(label.queue_free)

# Milestone Announcements & Celebrations
func _check_milestone(current_score: int) -> void:
	var milestone_titles = {
		10: "★ 10 BLOCKS - TOWER RISING! ★",
		20: "★ 20 BLOCKS - SKY HIGH! ★",
		30: "★ 30 BLOCKS - STRATOSPHERE! ★",
		40: "★ 40 BLOCKS - COSMIC REALM! ★",
		50: "★ 50 BLOCKS - MASTER BUILDER! ★",
		75: "★ 75 BLOCKS - CELESTIAL PINNACLE! ★",
		100: "★ 100 BLOCKS - TOWER OF ETERNITY! ★"
	}
	if milestone_titles.has(current_score):
		var title = milestone_titles[current_score]
		sound_mgr.play_milestone()
		trigger_screen_shake(0.35)
		_spawn_milestone_banner(title)
		_spawn_cosmic_background_ripple()
		if OS.has_feature("android"):
			Input.vibrate_handheld(120)

func _spawn_milestone_banner(text: String) -> void:
	var banner = Label.new()
	banner.text = text
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 30)
	banner.add_theme_color_override("font_color", Color(1.0, 0.95, 0.45))
	banner.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	banner.add_theme_constant_override("shadow_offset_x", 3)
	banner.add_theme_constant_override("shadow_offset_y", 3)
	
	var vp_size = get_viewport().get_visible_rect().size
	banner.size = Vector2(vp_size.x, 80)
	banner.position = Vector2(0, 220)
	banner.pivot_offset = Vector2(vp_size.x * 0.5, 40)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.scale = Vector2(0.5, 0.5)
	banner.modulate.a = 0.0
	
	ui_layer.add_child(banner)
	
	var tw = banner.create_tween()
	tw.set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(banner, "scale", Vector2.ONE, 0.35)
	tw.tween_property(banner, "modulate:a", 1.0, 0.25)
	tw.chain().tween_interval(1.2)
	tw.chain().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(banner, "scale", Vector2(1.2, 1.2), 0.3)
	tw.tween_property(banner, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(banner.queue_free)

func _transition_gradient_background(target_top: Color, target_bottom: Color) -> void:
	if not bg_gradient or bg_gradient.colors.size() < 2:
		return
	if bg_tween:
		bg_tween.kill()
	bg_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var current_top = bg_gradient.colors[0]
	var current_bottom = bg_gradient.colors[1]
	bg_tween.tween_method(func(c: Color):
		if bg_gradient and bg_gradient.colors.size() >= 2:
			bg_gradient.colors = PackedColorArray([c, bg_gradient.colors[1]])
	, current_top, target_top, 0.7)
	bg_tween.tween_method(func(c: Color):
		if bg_gradient and bg_gradient.colors.size() >= 2:
			bg_gradient.colors = PackedColorArray([bg_gradient.colors[0], c])
	, current_bottom, target_bottom, 0.7)
	
	# Harmonize floating stardust bokeh tint
	if is_instance_valid(bg_mote_particles):
		var mote_c = target_bottom.lerp(Color.WHITE, 0.45)
		mote_c.a = 0.45
		bg_mote_particles.color = mote_c

func _update_height_gradient_tint(height_index: int) -> void:
	if not bg_gradient:
		return
	var pal = PALETTES[palette_index % PALETTES.size()]
	var base_top = pal.get("bg_top", Color(0.08, 0.09, 0.18)) as Color
	var current_box_c = _get_box_shade(height_index)
	# Soft complementary atmospheric glow at the bottom of the gradient
	var dynamic_bottom = Color.from_hsv(current_box_c.h, 0.38, 0.24)
	_transition_gradient_background(base_top, dynamic_bottom)

func _setup_lighting_and_env() -> void:
	# Balanced lighting to keep colors rich and prevent white washout
	var env = $WorldEnvironment.environment
	if env:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.08, 0.09, 0.14) # Deep slate midnight
		env.ambient_light_color = Color(0.68, 0.72, 0.82)
		env.ambient_light_energy = 0.55
		env.glow_enabled = true
		env.glow_intensity = 0.30
		env.glow_bloom = 0.05
	
	var light = $DirectionalLight3D as DirectionalLight3D
	if light:
		light.light_color = Color(1.0, 1.0, 1.0)
		light.light_energy = 0.80

func _create_pedestal() -> void:
	base_pedestal = MeshInstance3D.new()
	var box_m = BoxMesh.new()
	box_m.size = Vector3(2.8, 1.4, 2.8)
	base_pedestal.mesh = box_m
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.19, 0.26)
	mat.metallic = 0.25
	mat.roughness = 0.35
	base_pedestal.material_override = mat
	base_pedestal.position = Vector3(0, -0.7, 0)
	add_child(base_pedestal)
	
	# Pedestal Top Accent Ring
	pedestal_rim = MeshInstance3D.new()
	var rim_mesh = BoxMesh.new()
	rim_mesh.size = Vector3(2.82, 0.06, 2.82)
	pedestal_rim.mesh = rim_mesh
	var rim_mat = StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.4, 0.6, 0.95)
	rim_mat.emission_enabled = true
	rim_mat.emission = Color(0.3, 0.6, 1.0)
	rim_mat.emission_energy_multiplier = 0.85
	pedestal_rim.material_override = rim_mat
	pedestal_rim.position = Vector3(0, 0.0, 0)
	add_child(pedestal_rim)

func reset_game() -> void:
	# Clear existing stack boxes
	for b in stack:
		if is_instance_valid(b):
			b.queue_free()
	stack.clear()
	
	if is_instance_valid(active_box):
		active_box.queue_free()
		active_box = null
	
	score = 0
	combo = 0
	state = GameState.READY
	current_top_y = 0.0
	current_target_pos = Vector3.ZERO
	target_camera_y = base_camera_pivot_y
	
	score_label.text = "0"
	combo_label.visible = false
	prompt_label.visible = true
	if not OS.has_feature("android") and not OS.has_feature("mobile"):
		prompt_label.text = "CLICK OR PRESS SPACE TO DROP"
	else:
		prompt_label.text = "TAP SCREEN TO DROP"
	game_over_panel.visible = false
	new_best_badge.visible = false
	
	# Cycle to next designer palette and randomize starting spectrum hue
	palette_index = (palette_index + 1) % PALETTES.size()
	current_palette_start_hue = randf()
	
	# Harmonize pedestal accent rim with the starting hue
	var first_box_color = _get_box_shade(0)
	if is_instance_valid(pedestal_rim) and pedestal_rim.material_override:
		var rm = pedestal_rim.material_override as StandardMaterial3D
		rm.albedo_color = first_box_color
		rm.emission = first_box_color
		rm.emission_energy_multiplier = 0.85
	
	# Update gradient background colors smoothly to match new palette
	var pal = PALETTES[palette_index % PALETTES.size()]
	var target_top = pal.get("bg_top", Color(0.08, 0.09, 0.18)) as Color
	var target_bottom = pal.get("bg_bottom", Color(0.20, 0.14, 0.28)) as Color
	_transition_gradient_background(target_top, target_bottom)
	
	# Initial slider level
	slider.set_target_level(current_top_y, current_target_pos, 0)
	slider.speed_multiplier = 1.0
	
	_spawn_next_box()

func _spawn_next_box() -> void:
	var new_box = StackBox.new()
	new_box.box_size = BOX_SIZE
	
	add_child(new_box)
	active_box = new_box
	
	# Dynamically generate a distinct shade from the SAME base color
	var box_color = _get_box_shade(stack.size())
	new_box.set_color(box_color)
	new_box.landed.connect(_on_box_landed)
	
	# Update slider level and slide axis (alternates X and Z)
	slider.set_target_level(current_top_y, current_target_pos, stack.size())
	slider.speed_multiplier = clamp(1.0 + (stack.size() * 0.03), 1.0, 2.4)
	slider.attach_box(new_box)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F11:
			var current_mode = DisplayServer.window_get_mode()
			if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			return
		elif event.keycode == KEY_M:
			_on_sound_btn_pressed()
			return
		elif event.keycode == KEY_R and state == GameState.GAME_OVER:
			restart_game()
			return

	var is_action = false
	if event is InputEventScreenTouch and event.pressed:
		is_action = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		is_action = true
	elif event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
		is_action = true
	
	if not is_action:
		return
	
	match state:
		GameState.READY:
			prompt_label.visible = false
			state = GameState.DROPPING
			_drop_current_box()
		GameState.PLAYING:
			state = GameState.DROPPING
			_drop_current_box()
		GameState.GAME_OVER:
			restart_game()

func _drop_current_box() -> void:
	if not is_instance_valid(active_box):
		return
	
	sound_mgr.play_drop()
	var box = slider.release_box()
	if box:
		box.drop(Vector3(0, -2.0, 0), current_top_y)

func _on_box_released(_box: Node3D, _pos: Vector3, _vel: Vector3) -> void:
	pass

func _on_box_landed(box: Node3D, _hit: bool) -> void:
	if state != GameState.DROPPING or box != active_box:
		return
	
	var drop_x = box.global_position.x
	var drop_z = box.global_position.z
	var target_x = current_target_pos.x
	var target_z = current_target_pos.z
	
	var dx = drop_x - target_x
	var dz = drop_z - target_z
	var dist = Vector2(dx, dz).length()
	
	if dist <= PERFECT_THRESHOLD:
		# PERFECT DROP!
		combo += 1
		if combo > best_combo:
			best_combo = combo
		score += 2
		
		# Snap to center
		box.global_position = Vector3(target_x, current_top_y + (BOX_SIZE.y * 0.5), target_z)
		current_target_pos = Vector3(target_x, 0, target_z)
		
		# Sympathetic compression on top block of stack
		if stack.size() > 0 and is_instance_valid(stack.back()) and stack.back().has_method("absorb_impact"):
			stack.back().absorb_impact()
		
		box.settle(true)
		
		sound_mgr.play_perfect(combo)
		_show_combo_fx(combo)
		_spawn_sparkle_fx(box.global_position)
		_trigger_cascade_wave()
		_on_box_placed_successfully(box)
		
	elif dist <= MAX_OVERHANG_DISTANCE:
		# GOOD DROP!
		combo = 0
		score += 1
		combo_label.visible = false
		
		# Settle at placed location
		current_target_pos = Vector3(drop_x, 0, drop_z)
		
		# Sympathetic compression on top block of stack
		if stack.size() > 0 and is_instance_valid(stack.back()) and stack.back().has_method("absorb_impact"):
			stack.back().absorb_impact()
		
		box.settle(false)
		
		sound_mgr.play_land()
		_spawn_impact_dust(box.global_position)
		_on_box_placed_successfully(box)
		
	else:
		# MISSED - TOPPLE OFF TOWER!
		state = GameState.GAME_OVER
		var topple_dir = Vector3(dx, 0, dz).normalized()
		box.start_topple(topple_dir)
		sound_mgr.play_game_over()
		trigger_screen_shake(0.7)
		_trigger_game_over()

func _trigger_cascade_wave() -> void:
	# Cascading neon ripple down the top few blocks of the tower
	var count = min(stack.size(), 4)
	for i in range(count):
		var b = stack[stack.size() - 1 - i]
		if is_instance_valid(b) and b.has_method("flash_sympathetic"):
			get_tree().create_timer((i + 1) * 0.05).timeout.connect(b.flash_sympathetic)

func _on_box_placed_successfully(box: Node3D) -> void:
	stack.append(box)
	current_top_y += BOX_SIZE.y
	
	# Update score UI with bounce animation
	score_label.text = str(score)
	_animate_score_bump()
	
	# Pan camera up smoothly
	target_camera_y = base_camera_pivot_y + current_top_y * 0.95
	
	# Gently evolve background gradient as the tower ascends
	_update_height_gradient_tint(stack.size())
	
	# Spawn next box
	state = GameState.PLAYING
	_spawn_next_box()

func _animate_score_bump() -> void:
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	score_label.scale = Vector2(1.35, 1.35)
	tween.tween_property(score_label, "scale", Vector2.ONE, 0.2)

func _show_combo_fx(current_combo: int) -> void:
	combo_label.text = "PERFECT x" + str(current_combo) + "!"
	combo_label.visible = true
	var tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	combo_label.scale = Vector2(1.5, 1.5)
	tween.tween_property(combo_label, "scale", Vector2.ONE, 0.35)

func _spawn_sparkle_fx(pos: Vector3) -> void:
	var particles = CPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.amount = 26
	particles.lifetime = 0.65
	particles.global_position = pos + Vector3(0, BOX_SIZE.y * 0.5, 0)
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 3.5
	particles.initial_velocity_max = 6.5
	particles.gravity = Vector3(0, -6.5, 0)
	particles.scale_amount_min = 0.1
	particles.scale_amount_max = 0.22
	particles.color = Color(1.0, 0.94, 0.74)
	
	var cube_mesh = BoxMesh.new()
	cube_mesh.size = Vector3(0.12, 0.12, 0.12)
	var cube_mat = StandardMaterial3D.new()
	cube_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	cube_mat.albedo_color = Color(1.0, 0.94, 0.74)
	cube_mesh.material = cube_mat
	particles.mesh = cube_mesh
	
	add_child(particles)
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)

func _spawn_impact_dust(pos: Vector3) -> void:
	var particles = CPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.88
	particles.amount = 16
	particles.lifetime = 0.45
	particles.global_position = pos - Vector3(0, BOX_SIZE.y * 0.4, 0)
	particles.direction = Vector3(0, 0.3, 0)
	particles.spread = 180.0
	particles.initial_velocity_min = 1.6
	particles.initial_velocity_max = 3.5
	particles.gravity = Vector3(0, -3.5, 0)
	particles.scale_amount_min = 0.08
	particles.scale_amount_max = 0.18
	particles.color = Color(0.92, 0.94, 0.98, 0.65)
	
	var dust_mesh = BoxMesh.new()
	dust_mesh.size = Vector3(0.08, 0.08, 0.08)
	var dust_mat = StandardMaterial3D.new()
	dust_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	dust_mat.albedo_color = Color(0.92, 0.94, 0.98, 0.65)
	dust_mesh.material = dust_mat
	particles.mesh = dust_mesh
	
	add_child(particles)
	get_tree().create_timer(0.8).timeout.connect(particles.queue_free)

func trigger_screen_shake(amount: float) -> void:
	screen_shake_trauma = clamp(screen_shake_trauma + amount, 0.0, 1.0)

func _process(delta: float) -> void:
	# Smooth camera tracking
	camera_pivot.position.y = lerp(camera_pivot.position.y, target_camera_y, delta * 3.5)
	
	# Screen shake decay
	if screen_shake_trauma > 0.0:
		screen_shake_trauma = max(screen_shake_trauma - delta * 2.0, 0.0)
		var shake = screen_shake_trauma * screen_shake_trauma * 0.4
		camera.h_offset = randf_range(-shake, shake)
		camera.v_offset = randf_range(-shake, shake)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0

func _trigger_game_over() -> void:
	# Haptic vibration on Android
	if OS.has_feature("android"):
		Input.vibrate_handheld(80)
	
	var is_new_record = false
	if score > high_score:
		high_score = score
		save_high_score()
		is_new_record = true
	
	final_score_label.text = "SCORE: " + str(score)
	best_score_label.text = "BEST: " + str(high_score)
	new_best_badge.visible = is_new_record
	
	# Animate game over panel slide in
	game_over_panel.visible = true
	game_over_panel.modulate.a = 0.0
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(game_over_panel, "modulate:a", 1.0, 0.3)

func restart_game() -> void:
	sound_mgr.play_click()
	reset_game()

func _on_sound_btn_pressed() -> void:
	var muted = sound_mgr.toggle_mute()
	sound_btn.text = "🔇" if muted else "🔊"

func save_high_score() -> void:
	var file = FileAccess.open("user://high_score.save", FileAccess.WRITE)
	if file:
		file.store_32(high_score)
		file.close()

func load_high_score() -> void:
	if FileAccess.file_exists("user://high_score.save"):
		var file = FileAccess.open("user://high_score.save", FileAccess.READ)
		if file:
			high_score = file.get_32()
			file.close()

func _setup_desktop_window_size() -> void:
	if not OS.has_feature("mobile") and not OS.has_feature("android"):
		var screen_id = DisplayServer.window_get_current_screen()
		var usable = DisplayServer.screen_get_usable_rect(screen_id)
		
		# Limit window height to 75% of usable desktop height or max 720px
		var target_h = int(clamp(usable.size.y * 0.75, 480.0, 720.0))
		var target_w = int(target_h * (720.0 / 1280.0)) # Exact 9:16 portrait ratio
		
		DisplayServer.window_set_size(Vector2i(target_w, target_h))
		
		# Center window comfortably on screen
		var pos_x = usable.position.x + (usable.size.x - target_w) / 2
		var pos_y = usable.position.y + (usable.size.y - target_h) / 2
		DisplayServer.window_set_position(Vector2i(pos_x, pos_y))

func _on_window_resized() -> void:
	var win_size = get_viewport().get_visible_rect().size
	if win_size.y > 0 and is_instance_valid(camera):
		var aspect = win_size.x / win_size.y
		var base_size = 11.5
		if aspect < 0.5625:
			# If narrower than standard portrait (9:16), zoom out camera slightly so nothing cuts off
			camera.size = base_size * (0.5625 / aspect)
		else:
			camera.size = base_size

# Generates smooth, vibrant gradient colors through curated designer palettes or prismatic rainbow
func _get_box_shade(index: int) -> Color:
	var pal = PALETTES[palette_index % PALETTES.size()]
	if pal["mode"] == "rainbow":
		var h = fmod(current_palette_start_hue + index * float(pal["speed"]), 1.0)
		return Color.from_hsv(h, float(pal["sat"]), float(pal["val"]))
	else:
		var colors = pal["colors"] as Array
		var count = colors.size()
		var step = index * 0.22 # Smooth transition every ~4-5 blocks
		var idx = int(step) % count
		var next_idx = (idx + 1) % count
		var t = fmod(step, 1.0)
		var smooth_t = (1.0 - cos(t * PI)) * 0.5
		return (colors[idx] as Color).lerp(colors[next_idx] as Color, smooth_t)
