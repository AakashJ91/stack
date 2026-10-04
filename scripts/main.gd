extends Node3D

const StackBox = preload("res://scripts/box.gd")
const CubeSlider = preload("res://scripts/cube_slider.gd")

enum GameState { MENU, READY, PLAYING, DROPPING, GAME_OVER }

var state: GameState = GameState.MENU
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
const BASE_CAMERA_SIZE: float = 12.8
var target_camera_y: float = 0.0
var base_camera_pivot_y: float = 0.0
var target_camera_x: float = 0.0
var target_camera_z: float = 0.0
var screen_shake_trauma: float = 0.0
var game_over_zoom_tween: Tween = null

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
@onready var home_btn = $UI/GameOverPanel/VBox/HomeBtn

# Main Menu & Ribbon UI
@onready var main_menu = $UI/MainMenu
@onready var top_section = $UI/MainMenu/TopSection
@onready var game_title = $UI/MainMenu/TopSection/GameTitle
@onready var menu_best_score = $UI/MainMenu/TopSection/MenuBestScore
@onready var tap_to_play_btn = $UI/MainMenu/TapToPlayBtn
@onready var tap_to_play_label = $UI/MainMenu/TapToPlayBtn/VBox/TapToPlayLabel
@onready var play_icon = $UI/MainMenu/TapToPlayBtn/VBox/PlayIcon
@onready var bottom_ribbon = $UI/MainMenu/BottomRibbon
@onready var btn_skin = $UI/MainMenu/BottomRibbon/HBox/BtnSkin
@onready var btn_challenge = $UI/MainMenu/BottomRibbon/HBox/BtnChallenge
@onready var btn_home = $UI/MainMenu/BottomRibbon/HBox/BtnHome
@onready var btn_levels = $UI/MainMenu/BottomRibbon/HBox/BtnLevels
@onready var drawer_modal = $UI/MainMenu/DrawerModal
@onready var drawer_title = $UI/MainMenu/DrawerModal/VBox/HeaderHBox/DrawerTitle
@onready var close_drawer_btn = $UI/MainMenu/DrawerModal/VBox/HeaderHBox/CloseDrawerBtn
@onready var drawer_content = $UI/MainMenu/DrawerModal/VBox/Scroll/ContentContainer

# Challenge & UI Modes
var active_challenge_id: String = "classic"
var challenge_speed_multiplier: float = 1.0
var challenge_perfect_multiplier: float = 1.0
var active_ribbon_tab: String = "home"
var tap_pulse_tween: Tween = null

var active_box: Node3D = null

var pedestal_rim: MeshInstance3D
var pedestal_mat: ShaderMaterial
var pedestal_mist_particles: CPUParticles3D
var fog_sheets: Array[MeshInstance3D] = []
var fog_materials: Array[ShaderMaterial] = []

# Gradient Background Components
var bg_quad: MeshInstance3D
var bg_gradient: Gradient
var bg_texture: GradientTexture2D
var bg_material: StandardMaterial3D
var bg_tween: Tween = null

# Textured Skins System
const SKIN_TEXTURES = {
	"marble": preload("res://textures/skin_marble.png"),
	"wood": preload("res://textures/skin_wood.png"),
	"cyber": preload("res://textures/skin_cyber.png"),
	"terrazzo": preload("res://textures/skin_terrazzo.png"),
}

const SKINS: Array[Dictionary] = [
	{
		"id": "classic",
		"name": "Classic Satin",
		"icon": "🧊",
		"desc": "Original clean beveled pastel blocks with smooth satin shading and ambient occlusion.",
		"type": "classic",
		"strength": 0.0,
		"emission": 0.0,
		"roughness": 0.32,
		"metallic": 0.03,
		"uv_scale": Vector2(0.65, 0.65)
	},
	{
		"id": "marble",
		"name": "Carrara Marble",
		"icon": "🏛️",
		"desc": "Polished Italian quartz with high-gloss crystalline veining and fine cracks.",
		"type": "textured",
		"strength": 0.70,
		"emission": 0.0,
		"roughness": 0.16,
		"metallic": 0.05,
		"uv_scale": Vector2(0.55, 0.55)
	},
	{
		"id": "wood",
		"name": "Nordic Cedar Wood",
		"icon": "🪵",
		"desc": "Warm organic cedar wood grain with ring bands and longitudinal grain fibers.",
		"type": "textured",
		"strength": 0.75,
		"emission": 0.0,
		"roughness": 0.42,
		"metallic": 0.02,
		"uv_scale": Vector2(0.60, 0.60)
	},
	{
		"id": "cyber",
		"name": "Cyber Holo Matrix",
		"icon": "⚡",
		"desc": "Futuristic isometric circuit grid with pulsating neon tech traces and node pads.",
		"type": "textured",
		"strength": 0.85,
		"emission": 1.4,
		"roughness": 0.25,
		"metallic": 0.12,
		"uv_scale": Vector2(0.85, 0.85)
	},
	{
		"id": "terrazzo",
		"name": "Modern Terrazzo Stone",
		"icon": "🪨",
		"desc": "Architectural composite stone with embedded polished quartz and mineral flakes.",
		"type": "textured",
		"strength": 0.68,
		"emission": 0.0,
		"roughness": 0.36,
		"metallic": 0.04,
		"uv_scale": Vector2(0.70, 0.70)
	}
]
var active_skin_id: String = "classic"

func get_current_skin_config() -> Dictionary:
	for s in SKINS:
		if s["id"] == active_skin_id:
			var cfg = s.duplicate()
			if s["id"] in SKIN_TEXTURES:
				cfg["texture"] = SKIN_TEXTURES[s["id"]]
			return cfg
	return SKINS[0].duplicate()

func _update_active_skins_in_scene() -> void:
	var skin_cfg = get_current_skin_config()
	if is_instance_valid(active_box) and active_box.has_method("apply_skin"):
		active_box.apply_skin(skin_cfg)
		if active_box.has_method("set_color"):
			active_box.set_color(_get_box_shade(stack.size()))
	for b in stack:
		if is_instance_valid(b) and b.has_method("apply_skin"):
			b.apply_skin(skin_cfg)

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
	_setup_realistic_fog_sheets()
	base_camera_pivot_y = camera_pivot.position.y
	target_camera_y = base_camera_pivot_y
	target_camera_x = camera_pivot.position.x
	target_camera_z = camera_pivot.position.z
	
	slider.box_released.connect(_on_box_released)
	sound_btn.pressed.connect(_on_sound_btn_pressed)
	$UI/GameOverPanel/VBox/RestartBtn.pressed.connect(restart_game)
	home_btn.pressed.connect(show_main_menu)
	
	_setup_ribbon_listeners()
	show_main_menu()

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
	
	if is_instance_valid(pedestal_mat):
		var cur_mist = pedestal_mat.get_shader_parameter("mist_color")
		if cur_mist == null:
			cur_mist = target_bottom
		bg_tween.tween_method(func(c: Color):
			if is_instance_valid(pedestal_mat):
				pedestal_mat.set_shader_parameter("mist_color", c)
		, cur_mist, target_bottom, 0.7)
	
	if is_instance_valid(pedestal_mist_particles):
		var mist_tint = target_bottom.lerp(Color.WHITE, 0.35)
		mist_tint.a = 0.25
		pedestal_mist_particles.color = mist_tint
	
	# Update realistic environment height fog color
	var env = $WorldEnvironment.environment
	if env and env.fog_enabled:
		var target_fog_c = target_bottom.lerp(Color(0.65, 0.75, 0.90), 0.25)
		bg_tween.tween_property(env, "fog_light_color", target_fog_c, 0.7)
	
	# Update rolling mist shader sheets color
	var target_sheet_c = target_bottom.lerp(Color(0.85, 0.90, 1.0), 0.18)
	for f_mat in fog_materials:
		if is_instance_valid(f_mat):
			var cur_fc = f_mat.get_shader_parameter("fog_color")
			if cur_fc == null:
				cur_fc = target_sheet_c
			bg_tween.tween_method(func(c: Color):
				if is_instance_valid(f_mat):
					f_mat.set_shader_parameter("fog_color", Color(c.r, c.g, c.b, 0.42))
			, cur_fc, target_sheet_c, 0.7)

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
		
		# Realistic Atmospheric Height Fog
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		var pal = PALETTES[palette_index % PALETTES.size()]
		var bot_c = pal.get("bg_bottom", Color(0.20, 0.14, 0.28)) as Color
		env.fog_light_color = bot_c.lerp(Color(0.65, 0.75, 0.90), 0.25)
		env.fog_light_energy = 0.95
		env.fog_density = 0.014
		env.fog_aerial_perspective = 0.45
		env.fog_sky_affect = 0.25
		env.fog_height = -0.5
		env.fog_height_density = 0.20
	
	var light = $DirectionalLight3D as DirectionalLight3D
	if light:
		light.light_color = Color(1.0, 1.0, 1.0)
		light.light_energy = 0.80

func _create_pedestal() -> void:
	# Elongated base pillar extending 24 units deep into the mist
	base_pedestal = MeshInstance3D.new()
	var box_m = BoxMesh.new()
	box_m.size = Vector3(2.8, 24.0, 2.8)
	base_pedestal.mesh = box_m
	
	var shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back;

uniform vec4 top_color : source_color = vec4(0.16, 0.19, 0.26, 1.0);
uniform vec4 mist_color : source_color = vec4(0.10, 0.13, 0.20, 0.0);
uniform float fade_start_y = -1.2;
uniform float fade_end_y = -18.0;
uniform float metallic : hint_range(0.0, 1.0) = 0.25;
uniform float roughness : hint_range(0.0, 1.0) = 0.35;

varying float v_world_y;

void vertex() {
	v_world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float t = clamp((v_world_y - fade_end_y) / (fade_start_y - fade_end_y), 0.0, 1.0);
	float fade = t * t * (3.0 - 2.0 * t); // Smooth Hermite curve
	
	vec3 col = mix(mist_color.rgb, top_color.rgb, fade);
	ALBEDO = col;
	ALPHA = fade;
	METALLIC = metallic * fade;
	ROUGHNESS = mix(0.9, roughness, fade);
}
"""
	pedestal_mat = ShaderMaterial.new()
	pedestal_mat.shader = shader
	var pal = PALETTES[palette_index % PALETTES.size()]
	var bot_c = pal.get("bg_bottom", Color(0.20, 0.14, 0.28)) as Color
	pedestal_mat.set_shader_parameter("top_color", Color(0.16, 0.19, 0.26, 1.0))
	pedestal_mat.set_shader_parameter("mist_color", bot_c)
	pedestal_mat.set_shader_parameter("fade_start_y", -1.2)
	pedestal_mat.set_shader_parameter("fade_end_y", -18.0)
	pedestal_mat.set_shader_parameter("metallic", 0.25)
	pedestal_mat.set_shader_parameter("roughness", 0.35)
	
	base_pedestal.material_override = pedestal_mat
	base_pedestal.position = Vector3(0, -12.0, 0)
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
	
	# Soft ethereal mist ring around the lower column
	_setup_pedestal_mist()

func _setup_pedestal_mist() -> void:
	pedestal_mist_particles = CPUParticles3D.new()
	pedestal_mist_particles.amount = 16
	pedestal_mist_particles.lifetime = 4.5
	pedestal_mist_particles.preprocess = 4.0
	pedestal_mist_particles.speed_scale = 0.75
	pedestal_mist_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	pedestal_mist_particles.emission_ring_radius = 2.5
	pedestal_mist_particles.emission_ring_inner_radius = 0.8
	pedestal_mist_particles.emission_ring_height = 4.0
	pedestal_mist_particles.emission_ring_axis = Vector3.UP
	pedestal_mist_particles.position = Vector3(0, -6.0, 0)
	pedestal_mist_particles.gravity = Vector3(0, 0.12, 0)
	pedestal_mist_particles.direction = Vector3(0, 0.5, 0)
	pedestal_mist_particles.spread = 180.0
	pedestal_mist_particles.initial_velocity_min = 0.06
	pedestal_mist_particles.initial_velocity_max = 0.18
	
	var mist_curve = Curve.new()
	mist_curve.add_point(Vector2(0.0, 0.0))
	mist_curve.add_point(Vector2(0.3, 0.85))
	mist_curve.add_point(Vector2(0.7, 0.85))
	mist_curve.add_point(Vector2(1.0, 0.0))
	pedestal_mist_particles.scale_amount_curve = mist_curve
	pedestal_mist_particles.scale_amount_min = 1.4
	pedestal_mist_particles.scale_amount_max = 2.8
	
	var quad = QuadMesh.new()
	quad.size = Vector2(2.8, 2.8)
	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	
	# Radial gradient for soft mist puff
	var tex = GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var g = Gradient.new()
	g.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.35),
		Color(1.0, 1.0, 1.0, 0.10),
		Color(1.0, 1.0, 1.0, 0.0)
	])
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	tex.gradient = g
	tex.width = 64
	tex.height = 64
	mat.albedo_texture = tex
	quad.material = mat
	
	pedestal_mist_particles.mesh = quad
	var pal = PALETTES[palette_index % PALETTES.size()]
	var bot_c = pal.get("bg_bottom", Color(0.20, 0.14, 0.28)) as Color
	var mist_tint = bot_c.lerp(Color.WHITE, 0.35)
	mist_tint.a = 0.25
	pedestal_mist_particles.color = mist_tint
	
	add_child(pedestal_mist_particles)

func _setup_realistic_fog_sheets() -> void:
	for sheet in fog_sheets:
		if is_instance_valid(sheet):
			sheet.queue_free()
	fog_sheets.clear()
	fog_materials.clear()
	
	# Procedural smooth simplex noise for rolling mist tendrils
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.016
	noise.fractal_octaves = 3
	
	var noise_tex = NoiseTexture2D.new()
	noise_tex.seamless = true
	noise_tex.noise = noise
	noise_tex.width = 256
	noise_tex.height = 256
	
	var fog_shader = Shader.new()
	fog_shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec4 fog_color : source_color = vec4(0.15, 0.18, 0.28, 0.45);
uniform vec2 scroll_speed = vec2(0.012, 0.008);
uniform vec2 scroll_speed2 = vec2(-0.008, 0.015);
uniform float density = 0.65;
uniform float edge_fade_radius = 24.0;

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv1 = v_world_pos.xz * 0.055 + TIME * scroll_speed;
	vec2 uv2 = v_world_pos.xz * 0.085 + TIME * scroll_speed2;
	
	float n1 = texture(noise_tex, uv1).r;
	float n2 = texture(noise_tex, uv2).r;
	float noise_val = smoothstep(0.12, 0.88, (n1 * 0.6 + n2 * 0.4));
	
	float dist = length(v_world_pos.xz);
	float circle_fade = clamp(1.0 - (dist / edge_fade_radius), 0.0, 1.0);
	circle_fade = circle_fade * circle_fade * (3.0 - 2.0 * circle_fade);
	
	ALBEDO = fog_color.rgb;
	ALPHA = noise_val * circle_fade * fog_color.a * density;
}
"""
	var pal = PALETTES[palette_index % PALETTES.size()]
	var bot_c = pal.get("bg_bottom", Color(0.20, 0.14, 0.28)) as Color
	var base_fog_color = bot_c.lerp(Color(0.85, 0.90, 1.0), 0.18)
	
	# Staggered height layers creating authentic 3D parallax depth
	var layer_configs = [
		{"y": -2.2, "size": 32.0, "density": 0.35, "s1": Vector2(0.014, 0.008), "s2": Vector2(-0.009, 0.015), "radius": 16.0},
		{"y": -4.6, "size": 42.0, "density": 0.50, "s1": Vector2(-0.011, 0.014), "s2": Vector2(0.015, -0.008), "radius": 22.0},
		{"y": -8.0, "size": 54.0, "density": 0.68, "s1": Vector2(0.018, -0.012), "s2": Vector2(-0.014, 0.010), "radius": 28.0},
		{"y": -12.5, "size": 68.0, "density": 0.85, "s1": Vector2(-0.015, -0.009), "s2": Vector2(0.012, 0.016), "radius": 34.0}
	]
	
	for cfg in layer_configs:
		var mat = ShaderMaterial.new()
		mat.shader = fog_shader
		mat.set_shader_parameter("noise_tex", noise_tex)
		mat.set_shader_parameter("fog_color", Color(base_fog_color.r, base_fog_color.g, base_fog_color.b, 0.42))
		mat.set_shader_parameter("density", cfg["density"])
		mat.set_shader_parameter("scroll_speed", cfg["s1"])
		mat.set_shader_parameter("scroll_speed2", cfg["s2"])
		mat.set_shader_parameter("edge_fade_radius", cfg["radius"])
		
		var mesh_inst = MeshInstance3D.new()
		var plane = PlaneMesh.new()
		plane.size = Vector2(cfg["size"], cfg["size"])
		mesh_inst.mesh = plane
		mesh_inst.material_override = mat
		mesh_inst.position = Vector3(0, cfg["y"], 0)
		mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		
		add_child(mesh_inst)
		fog_sheets.append(mesh_inst)
		fog_materials.append(mat)

const CHALLENGES: Array[Dictionary] = [
	{
		"id": "classic",
		"title": "🌈 Classic Stacker",
		"desc": "Original gentle ramp-up speed. Standard precision.",
		"speed": 1.0,
		"perf": 1.0
	},
	{
		"id": "speed",
		"title": "⚡ Speed Rush",
		"desc": "1.4x hyper slide speed. For twitch reflex masters!",
		"speed": 1.4,
		"perf": 1.0
	},
	{
		"id": "zen",
		"title": "🧘 Zen Harmony",
		"desc": "Relaxed 0.72x tempo & forgiving alignment. Pure tranquility.",
		"speed": 0.72,
		"perf": 1.25
	},
	{
		"id": "precision",
		"title": "💎 Precision Master",
		"desc": "Stricter perfect threshold with double bonus score (+4 pts)!",
		"speed": 1.08,
		"perf": 0.68
	}
]

const MILESTONES: Array[Dictionary] = [
	{"req": 5, "name": "Novice Stacker", "icon": "🥉", "desc": "Stack 5 blocks in a single run"},
	{"req": 15, "name": "Steady Builder", "icon": "🥈", "desc": "Reach a height of 15 blocks"},
	{"req": 30, "name": "Tower Specialist", "icon": "🥇", "desc": "Reach a height of 30 blocks"},
	{"req": 50, "name": "Sky Architect", "icon": "💎", "desc": "Construct a 50 block skyscraper"},
	{"req": 75, "name": "Cloud Piercer", "icon": "👑", "desc": "Surpass the clouds at 75 blocks"},
	{"req": 100, "name": "Cosmic Zenith", "icon": "🌌", "desc": "Reach the cosmos at 100 blocks"}
]

func show_main_menu() -> void:
	state = GameState.MENU
	if game_over_zoom_tween:
		game_over_zoom_tween.kill()
		game_over_zoom_tween = null
	
	# Clear existing stack boxes
	for b in stack:
		if is_instance_valid(b):
			b.queue_free()
	stack.clear()
	
	if is_instance_valid(active_box):
		active_box.queue_free()
		active_box = null
	
	# Reset camera to starting position
	target_camera_y = base_camera_pivot_y
	target_camera_x = 0.0
	target_camera_z = 0.0
	camera_pivot.position = Vector3(0.0, base_camera_pivot_y, 0.0)
	_on_window_resized()
	
	# Hide in-game HUD & Game Over panel
	score_label.visible = false
	combo_label.visible = false
	prompt_label.visible = false
	game_over_panel.visible = false
	
	# Show Main Menu
	main_menu.visible = true
	main_menu.modulate.a = 1.0
	menu_best_score.text = "BEST: " + str(high_score)
	
	# Close any open drawer and reset tab to home
	_close_drawer()
	_set_active_tab("home")
	
	# Start pulsing tap to play button
	_start_tap_pulse()
	
	# Setup attractive idling slider box over pedestal
	current_top_y = 0.0
	current_target_pos = Vector3.ZERO
	slider.set_target_level(current_top_y, current_target_pos, 0)
	slider.speed_multiplier = 0.85 * challenge_speed_multiplier
	_spawn_menu_preview_box()

func _spawn_menu_preview_box() -> void:
	if is_instance_valid(active_box):
		active_box.queue_free()
		active_box = null
	
	var new_box = StackBox.new()
	new_box.box_size = BOX_SIZE
	add_child(new_box)
	active_box = new_box
	var box_color = _get_box_shade(0)
	new_box.set_color(box_color)
	new_box.apply_skin(get_current_skin_config())
	slider.attach_box(new_box)

func _start_tap_pulse() -> void:
	if tap_pulse_tween:
		tap_pulse_tween.kill()
	tap_pulse_tween = create_tween().set_loops()
	tap_pulse_tween.tween_property(tap_to_play_btn, "modulate:a", 0.55, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tap_pulse_tween.tween_property(tap_to_play_btn, "modulate:a", 1.0, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func start_game_from_menu() -> void:
	if state != GameState.MENU:
		return
	
	sound_mgr.play_click()
	if tap_pulse_tween:
		tap_pulse_tween.kill()
		tap_pulse_tween = null
	
	_close_drawer()
	
	# Smooth fade-out of menu
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(main_menu, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func():
		main_menu.visible = false
	)
	
	score = 0
	combo = 0
	state = GameState.READY
	current_top_y = 0.0
	current_target_pos = Vector3.ZERO
	
	score_label.text = "0"
	score_label.visible = true
	combo_label.visible = false
	prompt_label.visible = true
	if not OS.has_feature("android") and not OS.has_feature("mobile"):
		prompt_label.text = "CLICK OR PRESS SPACE TO DROP"
	else:
		prompt_label.text = "TAP SCREEN TO DROP"
	
	slider.speed_multiplier = 1.0 * challenge_speed_multiplier
	if is_instance_valid(active_box):
		active_box.landed.connect(_on_box_landed)

func _setup_ribbon_listeners() -> void:
	tap_to_play_btn.pressed.connect(start_game_from_menu)
	btn_home.pressed.connect(func():
		sound_mgr.play_click()
		_close_drawer()
		_set_active_tab("home")
	)
	btn_skin.pressed.connect(func():
		sound_mgr.play_click()
		_set_active_tab("skin")
		_open_skins_drawer()
	)
	btn_challenge.pressed.connect(func():
		sound_mgr.play_click()
		_set_active_tab("challenge")
		_open_challenge_drawer()
	)
	btn_levels.pressed.connect(func():
		sound_mgr.play_click()
		_set_active_tab("levels")
		_open_levels_drawer()
	)
	close_drawer_btn.pressed.connect(func():
		sound_mgr.play_click()
		_close_drawer()
		_set_active_tab("home")
	)

func _set_active_tab(tab_name: String) -> void:
	active_ribbon_tab = tab_name
	
	var active_style = StyleBoxFlat.new()
	active_style.bg_color = Color(0.20, 0.38, 0.68, 0.85)
	active_style.set_corner_radius_all(20)
	
	var inactive_style = StyleBoxFlat.new()
	inactive_style.bg_color = Color(0, 0, 0, 0)
	
	var tabs = {
		"skin": btn_skin,
		"challenge": btn_challenge,
		"home": btn_home,
		"levels": btn_levels
	}
	
	for key in tabs.keys():
		var btn: Button = tabs[key]
		if key == tab_name:
			btn.add_theme_stylebox_override("normal", active_style)
			btn.add_theme_stylebox_override("hover", active_style)
			btn.add_theme_stylebox_override("pressed", active_style)
			btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		else:
			btn.add_theme_stylebox_override("normal", inactive_style)
			btn.add_theme_stylebox_override("hover", inactive_style)
			btn.add_theme_stylebox_override("pressed", inactive_style)
			btn.add_theme_color_override("font_color", Color(0.70, 0.76, 0.88, 0.75))

func _open_drawer(title_text: String) -> void:
	drawer_title.text = title_text
	drawer_modal.visible = true
	drawer_modal.modulate.a = 0.0
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(drawer_modal, "modulate:a", 1.0, 0.22)
	
	for child in drawer_content.get_children():
		child.queue_free()

func _close_drawer() -> void:
	drawer_modal.visible = false

func _create_card_container() -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.15, 0.23, 0.95)
	style.border_color = Color(0.26, 0.36, 0.58, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _create_card_button(btn_text: String, is_active: bool) -> Button:
	var btn = Button.new()
	btn.text = btn_text
	btn.custom_minimum_size = Vector2(0, 36)
	btn.add_theme_font_size_override("font_size", 14)
	var btn_style = StyleBoxFlat.new()
	btn_style.set_corner_radius_all(10)
	if is_active:
		btn_style.bg_color = Color(0.18, 0.65, 0.45, 0.92)
		btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	else:
		btn_style.bg_color = Color(0.20, 0.40, 0.75, 0.9)
		btn.add_theme_color_override("font_color", Color(0.95, 0.96, 1, 1))
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.add_theme_stylebox_override("hover", btn_style)
	btn.add_theme_stylebox_override("pressed", btn_style)
	return btn

func _open_skins_drawer() -> void:
	_open_drawer("STACK SKINS")
	
	# --- SECTION 1: CLASSIC SATIN SKIN & COLOR OPTIONS ---
	var classic_section_lbl = Label.new()
	classic_section_lbl.text = "🧊 CLASSIC SATIN SKIN & COLOR OPTIONS"
	classic_section_lbl.add_theme_font_size_override("font_size", 14)
	classic_section_lbl.add_theme_color_override("font_color", Color(0.78, 0.85, 1.0, 0.9))
	drawer_content.add_child(classic_section_lbl)
	
	var is_classic_active = (active_skin_id == "classic")
	var classic_card = _create_card_container()
	var c_vbox = VBoxContainer.new()
	c_vbox.add_theme_constant_override("separation", 10)
	classic_card.add_child(c_vbox)
	
	# Classic Header Row
	var c_header = HBoxContainer.new()
	var c_title = Label.new()
	c_title.text = "🧊 Classic Satin Finish"
	c_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c_title.add_theme_font_size_override("font_size", 16)
	c_title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	c_header.add_child(c_title)
	
	if is_classic_active:
		var c_badge = Label.new()
		c_badge.text = "✓ ACTIVE"
		c_badge.add_theme_font_size_override("font_size", 13)
		c_badge.add_theme_color_override("font_color", Color(0.35, 0.90, 0.55, 1.0))
		c_header.add_child(c_badge)
	c_vbox.add_child(c_header)
	
	var c_desc = Label.new()
	c_desc.text = "Original minimalist beveled pastel blocks with soft edge ambient occlusion."
	c_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c_desc.add_theme_font_size_override("font_size", 13)
	c_desc.add_theme_color_override("font_color", Color(0.72, 0.78, 0.90, 0.85))
	c_vbox.add_child(c_desc)
	
	if not is_classic_active:
		var equip_classic_btn = _create_card_button("EQUIP CLASSIC SATIN SKIN", false)
		equip_classic_btn.pressed.connect(func():
			active_skin_id = "classic"
			sound_mgr.play_click()
			_update_active_skins_in_scene()
			_open_skins_drawer()
		)
		c_vbox.add_child(equip_classic_btn)
	
	# Color Palettes header inside classic card
	var pal_subhead = Label.new()
	pal_subhead.text = "🎨 COLOR PALETTES FOR CLASSIC SKIN:"
	pal_subhead.add_theme_font_size_override("font_size", 12)
	pal_subhead.add_theme_color_override("font_color", Color(0.65, 0.75, 0.90, 0.75))
	c_vbox.add_child(pal_subhead)
	
	for i in range(PALETTES.size()):
		var pal = PALETTES[i]
		var is_pal_active = (is_classic_active and i == palette_index)
		
		var pal_row = PanelContainer.new()
		var p_style = StyleBoxFlat.new()
		p_style.bg_color = Color(0.09, 0.11, 0.18, 0.8)
		p_style.set_corner_radius_all(10)
		p_style.content_margin_left = 12
		p_style.content_margin_right = 12
		p_style.content_margin_top = 8
		p_style.content_margin_bottom = 8
		if is_pal_active:
			p_style.border_color = Color(0.35, 0.75, 1.0, 0.8)
			p_style.set_border_width_all(1)
		pal_row.add_theme_stylebox_override("panel", p_style)
		
		var row_vbox = VBoxContainer.new()
		row_vbox.add_theme_constant_override("separation", 6)
		pal_row.add_child(row_vbox)
		
		var top_line = HBoxContainer.new()
		var name_lbl = Label.new()
		name_lbl.text = pal.get("name", "Palette " + str(i + 1))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0, 1.0))
		top_line.add_child(name_lbl)
		
		if is_pal_active:
			var equipped_lbl = Label.new()
			equipped_lbl.text = "✓ EQUIPPED"
			equipped_lbl.add_theme_font_size_override("font_size", 12)
			equipped_lbl.add_theme_color_override("font_color", Color(0.35, 0.90, 0.55, 1.0))
			top_line.add_child(equipped_lbl)
		row_vbox.add_child(top_line)
		
		# Swatches
		var swatches_row = HBoxContainer.new()
		swatches_row.add_theme_constant_override("separation", 6)
		if pal.get("mode", "") == "rainbow":
			var sample_hues = [0.0, 0.16, 0.33, 0.5, 0.66, 0.83]
			for h in sample_hues:
				var swatch = ColorRect.new()
				swatch.custom_minimum_size = Vector2(28, 18)
				swatch.color = Color.from_hsv(h, float(pal.get("sat", 0.54)), float(pal.get("val", 0.92)))
				swatches_row.add_child(swatch)
		else:
			var colors = pal.get("colors", []) as Array
			for c in colors:
				var swatch = ColorRect.new()
				swatch.custom_minimum_size = Vector2(28, 18)
				swatch.color = c as Color
				swatches_row.add_child(swatch)
		row_vbox.add_child(swatches_row)
		
		if not is_pal_active:
			var apply_btn = _create_card_button("APPLY PALETTE", false)
			var chosen_idx = i
			apply_btn.pressed.connect(func():
				active_skin_id = "classic"
				palette_index = chosen_idx
				sound_mgr.play_click()
				var p_data = PALETTES[palette_index]
				var top_c = p_data.get("bg_top", Color(0.08, 0.09, 0.18)) as Color
				var bot_c = p_data.get("bg_bottom", Color(0.20, 0.14, 0.28)) as Color
				_transition_gradient_background(top_c, bot_c)
				
				var first_color = _get_box_shade(0)
				if is_instance_valid(pedestal_rim) and pedestal_rim.material_override:
					var rm = pedestal_rim.material_override as StandardMaterial3D
					rm.albedo_color = first_color
					rm.emission = first_color
				_update_active_skins_in_scene()
				_open_skins_drawer()
			)
			row_vbox.add_child(apply_btn)
		
		c_vbox.add_child(pal_row)
	
	drawer_content.add_child(classic_card)
	
	# --- SECTION 2: NEW TEXTURED SKINS ---
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	drawer_content.add_child(spacer)
	
	var texture_section_lbl = Label.new()
	texture_section_lbl.text = "✨ NEW TEXTURED SKINS"
	texture_section_lbl.add_theme_font_size_override("font_size", 14)
	texture_section_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.40, 0.95))
	drawer_content.add_child(texture_section_lbl)
	
	for s in SKINS:
		if s["type"] != "textured":
			continue
		
		var is_equipped = (active_skin_id == s["id"])
		var card = _create_card_container()
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 8)
		card.add_child(vbox)
		
		# Header
		var header_row = HBoxContainer.new()
		var title_lbl = Label.new()
		title_lbl.text = s["icon"] + " " + s["name"]
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_lbl.add_theme_font_size_override("font_size", 16)
		title_lbl.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0, 1.0))
		header_row.add_child(title_lbl)
		
		if is_equipped:
			var badge = Label.new()
			badge.text = "✓ EQUIPPED"
			badge.add_theme_font_size_override("font_size", 13)
			badge.add_theme_color_override("font_color", Color(0.35, 0.90, 0.55, 1.0))
			header_row.add_child(badge)
		vbox.add_child(header_row)
		
		# Description
		var desc_lbl = Label.new()
		desc_lbl.text = s["desc"]
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 13)
		desc_lbl.add_theme_color_override("font_color", Color(0.72, 0.78, 0.90, 0.85))
		vbox.add_child(desc_lbl)
		
		# Material Highlights Tag
		var tag_lbl = Label.new()
		var tag_text = ""
		if s["id"] == "marble":
			tag_text = "💎 Polished Specular | Italian Quartz Veining"
		elif s["id"] == "wood":
			tag_text = "🌲 Satin Cedar | Elongated Organic Grain Rings"
		elif s["id"] == "cyber":
			tag_text = "⚡ Glowing Neon Traces | Dual Isometric Grid"
		elif s["id"] == "terrazzo":
			tag_text = "🪨 Multi-tone Chips | Modern Architectural Composite"
		tag_lbl.text = tag_text
		tag_lbl.add_theme_font_size_override("font_size", 12)
		tag_lbl.add_theme_color_override("font_color", Color(0.65, 0.78, 0.95, 0.75))
		vbox.add_child(tag_lbl)
		
		# Action button
		var btn = _create_card_button("✓ EQUIPPED" if is_equipped else "EQUIP " + s["name"].to_upper(), is_equipped)
		if not is_equipped:
			var skin_id = s["id"]
			btn.pressed.connect(func():
				active_skin_id = skin_id
				sound_mgr.play_click()
				_update_active_skins_in_scene()
				_open_skins_drawer()
			)
		vbox.add_child(btn)
		drawer_content.add_child(card)

func _open_challenge_drawer() -> void:
	_open_drawer("CHALLENGE MODES")
	
	for c in CHALLENGES:
		var is_active = (c["id"] == active_challenge_id)
		var card = _create_card_container()
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)
		card.add_child(vbox)
		
		# Header
		var header_row = HBoxContainer.new()
		var title_lbl = Label.new()
		title_lbl.text = c["title"]
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_lbl.add_theme_font_size_override("font_size", 16)
		title_lbl.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0, 1.0))
		header_row.add_child(title_lbl)
		
		if is_active:
			var badge = Label.new()
			badge.text = "✓ ACTIVE"
			badge.add_theme_font_size_override("font_size", 13)
			badge.add_theme_color_override("font_color", Color(0.35, 0.90, 0.55, 1.0))
			header_row.add_child(badge)
		vbox.add_child(header_row)
		
		# Description
		var desc_lbl = Label.new()
		desc_lbl.text = c["desc"]
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 13)
		desc_lbl.add_theme_color_override("font_color", Color(0.72, 0.78, 0.90, 0.85))
		vbox.add_child(desc_lbl)
		
		# Action button
		var btn = _create_card_button("✓ ACTIVE" if is_active else "PLAY CHALLENGE", is_active)
		if not is_active:
			var cid = c["id"]
			var c_speed = c["speed"]
			var c_perf = c["perf"]
			btn.pressed.connect(func():
				active_challenge_id = cid
				challenge_speed_multiplier = c_speed
				challenge_perfect_multiplier = c_perf
				sound_mgr.play_click()
				if state == GameState.MENU:
					slider.speed_multiplier = 0.85 * challenge_speed_multiplier
				_open_challenge_drawer()
			)
		vbox.add_child(btn)
		drawer_content.add_child(card)

func _open_levels_drawer() -> void:
	_open_drawer("LEVEL MILESTONES")
	
	# Current Title / Rank Header Card
	var rank_title = "APPRENTICE"
	if high_score >= 100: rank_title = "COSMIC ZENITH 🌌"
	elif high_score >= 75: rank_title = "CLOUD PIERCER 👑"
	elif high_score >= 50: rank_title = "SKY ARCHITECT 💎"
	elif high_score >= 30: rank_title = "TOWER SPECIALIST 🥇"
	elif high_score >= 15: rank_title = "STEADY BUILDER 🥈"
	elif high_score >= 5: rank_title = "NOVICE STACKER 🥉"
	
	var summary_card = _create_card_container()
	var s_vbox = VBoxContainer.new()
	s_vbox.add_theme_constant_override("separation", 4)
	summary_card.add_child(s_vbox)
	
	var rank_lbl = Label.new()
	rank_lbl.text = "CURRENT TITLE: " + rank_title
	rank_lbl.add_theme_font_size_override("font_size", 16)
	rank_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35, 1.0))
	rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s_vbox.add_child(rank_lbl)
	
	var best_lbl = Label.new()
	best_lbl.text = "All-Time Best Record: " + str(high_score) + " Blocks"
	best_lbl.add_theme_font_size_override("font_size", 13)
	best_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95, 0.85))
	best_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s_vbox.add_child(best_lbl)
	drawer_content.add_child(summary_card)
	
	# Milestones list
	for m in MILESTONES:
		var unlocked = high_score >= m["req"]
		var card = _create_card_container()
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)
		card.add_child(vbox)
		
		# Header
		var header_row = HBoxContainer.new()
		var title_lbl = Label.new()
		title_lbl.text = m["icon"] + " " + m["name"]
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_lbl.add_theme_font_size_override("font_size", 15)
		title_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0) if unlocked else Color(0.70, 0.75, 0.85, 0.75))
		header_row.add_child(title_lbl)
		
		var status_lbl = Label.new()
		if unlocked:
			status_lbl.text = "✓ UNLOCKED"
			status_lbl.add_theme_color_override("font_color", Color(0.35, 0.90, 0.55, 1.0))
		else:
			status_lbl.text = "🔒 " + str(high_score) + "/" + str(m["req"])
			status_lbl.add_theme_color_override("font_color", Color(0.65, 0.70, 0.80, 0.75))
		status_lbl.add_theme_font_size_override("font_size", 13)
		header_row.add_child(status_lbl)
		vbox.add_child(header_row)
		
		# Description
		var desc_lbl = Label.new()
		desc_lbl.text = m["desc"]
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.70, 0.82, 0.75))
		vbox.add_child(desc_lbl)
		
		# Progress bar
		var p_bar = ProgressBar.new()
		p_bar.custom_minimum_size = Vector2(0, 10)
		p_bar.show_percentage = false
		p_bar.max_value = float(m["req"])
		p_bar.value = clamp(float(high_score), 0.0, float(m["req"]))
		var bg_style = StyleBoxFlat.new()
		bg_style.bg_color = Color(0.18, 0.22, 0.32, 0.6)
		bg_style.set_corner_radius_all(5)
		var fill_style = StyleBoxFlat.new()
		fill_style.bg_color = Color(0.35, 0.85, 0.55, 0.9) if unlocked else Color(0.25, 0.55, 0.85, 0.85)
		fill_style.set_corner_radius_all(5)
		p_bar.add_theme_stylebox_override("background", bg_style)
		p_bar.add_theme_stylebox_override("fill", fill_style)
		vbox.add_child(p_bar)
		
		drawer_content.add_child(card)

func reset_game() -> void:
	# Clear existing stack boxes
	for b in stack:
		if is_instance_valid(b):
			b.queue_free()
	stack.clear()
	
	if is_instance_valid(active_box):
		active_box.queue_free()
		active_box = null
	
	if game_over_zoom_tween:
		game_over_zoom_tween.kill()
		game_over_zoom_tween = null
	
	score = 0
	combo = 0
	state = GameState.READY
	current_top_y = 0.0
	current_target_pos = Vector3.ZERO
	target_camera_y = base_camera_pivot_y
	target_camera_x = 0.0
	target_camera_z = 0.0
	camera_pivot.position = Vector3(0.0, base_camera_pivot_y, 0.0)
	_on_window_resized()
	
	main_menu.visible = false
	score_label.text = "0"
	score_label.visible = true
	combo_label.visible = false
	prompt_label.visible = true
	if not OS.has_feature("android") and not OS.has_feature("mobile"):
		prompt_label.text = "CLICK OR PRESS SPACE TO DROP"
	else:
		prompt_label.text = "TAP SCREEN TO DROP"
	game_over_panel.visible = false
	new_best_badge.visible = false
	
	# Initial slider level
	slider.set_target_level(current_top_y, current_target_pos, 0)
	slider.speed_multiplier = 1.0 * challenge_speed_multiplier
	
	_spawn_next_box()

func _spawn_next_box() -> void:
	var new_box = StackBox.new()
	new_box.box_size = BOX_SIZE
	
	add_child(new_box)
	active_box = new_box
	
	# Dynamically generate a distinct shade from the SAME base color
	var box_color = _get_box_shade(stack.size())
	new_box.set_color(box_color)
	new_box.apply_skin(get_current_skin_config())
	new_box.landed.connect(_on_box_landed)
	
	# Update slider level and slide axis (alternates X and Z)
	slider.set_target_level(current_top_y, current_target_pos, stack.size())
	slider.speed_multiplier = clamp((1.0 + (stack.size() * 0.03)) * challenge_speed_multiplier, 0.65, 3.2)
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
		elif event.keycode == KEY_ESCAPE:
			if state == GameState.MENU and drawer_modal.visible:
				_close_drawer()
				_set_active_tab("home")
				return
			elif state == GameState.PLAYING or state == GameState.READY:
				show_main_menu()
				return

	var is_action = false
	if event is InputEventScreenTouch and event.pressed:
		# If the skins/challenge/levels drawer is open, only act on taps OUTSIDE the drawer.
		# Touches inside the drawer must reach the ScrollContainer for scrolling.
		if drawer_modal.visible:
			var touch_pos: Vector2 = event.position
			var drawer_rect: Rect2 = drawer_modal.get_global_rect()
			if drawer_rect.has_point(touch_pos):
				return  # Let the ScrollContainer / buttons handle it
		is_action = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		is_action = true
	elif event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
		is_action = true
	
	if not is_action:
		return
	
	match state:
		GameState.MENU:
			if not drawer_modal.visible:
				start_game_from_menu()
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
	
	if dist <= (PERFECT_THRESHOLD * challenge_perfect_multiplier):
		# PERFECT DROP!
		combo += 1
		if combo > best_combo:
			best_combo = combo
		score += (4 if active_challenge_id == "precision" else 2)
		
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
	# Vertical camera tracking follows the rising stack
	camera_pivot.position.y = lerp(camera_pivot.position.y, target_camera_y, delta * 3.5)
	
	# Horizontal camera tracking: only adjust if the stack drifts towards screen boundaries
	if state != GameState.GAME_OVER and is_instance_valid(camera):
		var stack_top = Vector3(current_target_pos.x, current_top_y + (BOX_SIZE.y * 0.5), current_target_pos.z)
		var screen_pos = camera.unproject_position(stack_top)
		var vp_size = get_viewport().get_visible_rect().size
		if vp_size.x > 0.0 and vp_size.y > 0.0:
			var norm_x = screen_pos.x / vp_size.x
			# If stack top drifts past comfortable framing boundaries (outside 35% - 65% of screen width),
			# adjust target horizontal camera coordinates to re-center the stack
			if norm_x < 0.35 or norm_x > 0.65:
				target_camera_x = current_target_pos.x
				target_camera_z = current_target_pos.z
	
	camera_pivot.position.x = lerp(camera_pivot.position.x, target_camera_x, delta * 3.0)
	camera_pivot.position.z = lerp(camera_pivot.position.z, target_camera_z, delta * 3.0)
	
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
	
	# Cinematic camera zoom-out to reveal the full tower
	_animate_game_over_tower_reveal()
	
	# Animate game over panel slide in after a short reveal beat
	game_over_panel.visible = true
	game_over_panel.modulate.a = 0.0
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.65)
	tween.tween_property(game_over_panel, "modulate:a", 1.0, 0.45)

func _animate_game_over_tower_reveal() -> void:
	if not is_instance_valid(camera) or not is_instance_valid(camera_pivot):
		return
	
	if game_over_zoom_tween:
		game_over_zoom_tween.kill()
	
	var aspect_mult = 1.0
	var win_size = get_viewport().get_visible_rect().size
	if win_size.y > 0.0:
		var aspect = win_size.x / win_size.y
		if aspect < 0.5625:
			aspect_mult = 0.5625 / aspect
	
	var H = current_top_y
	var raw_needed_size = max(14.5, (H + 5.0) * 1.45)
	var target_zoom_size = raw_needed_size * aspect_mult
	
	# Center camera vertically on the full tower
	var tower_center_y = (H * 0.5) + 1.2
	# Center camera horizontally (handles leaning towers)
	var tower_center_x = current_target_pos.x * 0.5
	var tower_center_z = current_target_pos.z * 0.5
	
	game_over_zoom_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	game_over_zoom_tween.tween_property(camera, "size", target_zoom_size, 1.7)
	game_over_zoom_tween.tween_property(self, "target_camera_y", tower_center_y, 1.7)
	game_over_zoom_tween.tween_property(self, "target_camera_x", tower_center_x, 1.7)
	game_over_zoom_tween.tween_property(self, "target_camera_z", tower_center_z, 1.7)

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
		var aspect_mult = (0.5625 / aspect) if aspect < 0.5625 else 1.0
		if state == GameState.GAME_OVER:
			var H = current_top_y
			var raw_needed_size = max(14.5, (H + 5.0) * 1.45)
			camera.size = raw_needed_size * aspect_mult
		else:
			camera.size = BASE_CAMERA_SIZE * aspect_mult

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
