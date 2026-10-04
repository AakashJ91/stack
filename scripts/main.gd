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

# Curated high-aesthetic color palettes for stacking runs
# Modes: "rainbow" (continuous silky spectrum) and "gradient" (harmonious designer colorways)
const PALETTES: Array[Dictionary] = [
	{
		"name": "Prismatic Spectrum",
		"mode": "rainbow",
		"speed": 0.026,
		"sat": 0.78,
		"val": 0.95
	},
	{
		"name": "Cyber Sunset",
		"mode": "gradient",
		"colors": [
			Color(0.58, 0.18, 0.96), # Electric Violet
			Color(0.92, 0.12, 0.68), # Magenta Fuchsia
			Color(0.98, 0.28, 0.38), # Neon Coral
			Color(1.00, 0.52, 0.12), # Sunset Orange
			Color(1.00, 0.78, 0.18), # Golden Amber
			Color(0.96, 0.38, 0.65)  # Rose Quartz
		]
	},
	{
		"name": "Ocean Aurora",
		"mode": "gradient",
		"colors": [
			Color(0.12, 0.38, 0.98), # Royal Cobalt
			Color(0.08, 0.65, 0.98), # Electric Blue
			Color(0.05, 0.88, 0.85), # Neon Turquoise
			Color(0.12, 0.95, 0.58), # Mint Emerald
			Color(0.20, 0.82, 0.98)  # Cyan Glow
		]
	},
	{
		"name": "Royal Jewels",
		"mode": "gradient",
		"colors": [
			Color(0.55, 0.12, 0.92), # Imperial Amethyst
			Color(0.88, 0.10, 0.40), # Crimson Ruby
			Color(0.98, 0.35, 0.15), # Fire Opal
			Color(1.00, 0.72, 0.14), # Citrine Gold
			Color(0.78, 0.15, 0.82)  # Vivid Orchid
		]
	},
	{
		"name": "Synthwave Neon",
		"mode": "gradient",
		"colors": [
			Color(0.35, 0.15, 0.95), # Cyber Indigo
			Color(0.98, 0.12, 0.62), # Hot Neon Pink
			Color(0.72, 0.25, 0.95), # Bright Lavender
			Color(0.05, 0.82, 0.95)  # Electric Aqua
		]
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
	_create_pedestal()
	base_camera_pivot_y = camera_pivot.position.y
	target_camera_y = base_camera_pivot_y
	
	slider.box_released.connect(_on_box_released)
	sound_btn.pressed.connect(_on_sound_btn_pressed)
	$UI/GameOverPanel/VBox/RestartBtn.pressed.connect(restart_game)
	
	reset_game()

func _setup_lighting_and_env() -> void:
	# Subtle background tint and directional isometric shadows
	var env = $WorldEnvironment.environment
	if env:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.08, 0.09, 0.14) # Deep slate midnight
		env.ambient_light_color = Color(0.72, 0.78, 0.90)
		env.ambient_light_energy = 0.80
		env.glow_enabled = true
		env.glow_intensity = 0.65
		env.glow_bloom = 0.16
	
	var light = $DirectionalLight3D as DirectionalLight3D
	if light:
		light.light_color = Color(1.0, 0.98, 0.94)
		light.light_energy = 1.15

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
	particles.color = Color(1.0, 0.9, 0.35)
	
	var cube_mesh = BoxMesh.new()
	cube_mesh.size = Vector3(0.12, 0.12, 0.12)
	var cube_mat = StandardMaterial3D.new()
	cube_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	cube_mat.albedo_color = Color(1.0, 0.92, 0.4)
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
	particles.color = Color(0.9, 0.92, 1.0, 0.7)
	
	var dust_mesh = BoxMesh.new()
	dust_mesh.size = Vector3(0.08, 0.08, 0.08)
	var dust_mat = StandardMaterial3D.new()
	dust_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	dust_mat.albedo_color = Color(0.9, 0.92, 1.0, 0.7)
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
