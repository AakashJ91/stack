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
@onready var exp_badge_btn: Button = $UI/HUD/ExpBadgeBtn
@onready var sound_btn = $UI/HUD/SoundBtn
@onready var play_close_btn: Button = $UI/HUD/PlayCloseBtn
@onready var game_over_close_btn: Button = $UI/HUD/GameOverCloseBtn
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
@onready var btn_campaign = $UI/MainMenu/BottomRibbon/HBox/BtnCampaign
@onready var btn_levels = $UI/MainMenu/BottomRibbon/HBox/BtnLevels
@onready var drawer_modal = $UI/MainMenu/DrawerModal
@onready var drawer_title = $UI/MainMenu/DrawerModal/VBox/HeaderHBox/DrawerTitle
@onready var close_drawer_btn = $UI/MainMenu/DrawerModal/VBox/HeaderHBox/CloseDrawerBtn
@onready var drawer_content = $UI/MainMenu/DrawerModal/VBox/Scroll/ContentContainer
@onready var drawer_scroll: ScrollContainer = $UI/MainMenu/DrawerModal/VBox/Scroll

# Challenge & UI Modes
var active_challenge_id: String = "classic"
var challenge_speed_multiplier: float = 1.0
var challenge_perfect_multiplier: float = 1.0
var active_ribbon_tab: String = "home"
var tap_pulse_tween: Tween = null
var play_again_pulse_tween: Tween = null
var drawer_tween: Tween = null
var _game_over_time: int = 0
var _is_restarting: bool = false
var _restart_tween: Tween = null

# Smooth Touch & Drag Scrolling Controller
var _scroll_touch_active: bool = false
var _scroll_touch_index: int = -1
var _scroll_start_y: float = 0.0
var _scroll_start_val: int = 0
var _scroll_is_dragging: bool = false
var _scroll_velocity_y: float = 0.0
var _scroll_last_pos_y: float = 0.0
var _scroll_last_pos_time: int = 0
var _scroll_last_drag_time: int = 0

# Experience (EXP) & Daily Missions System
const EXP_SAVE_PATH: String = "user://exp_data.json"
var total_exp: int = 0
var exp_today_date: String = ""
var login_claimed_date: String = ""
var perfect_3_claimed_date: String = ""
var stack_50_claimed_date: String = ""
var stack_100_claimed_date: String = ""
var daily_best_combo: int = 0
var daily_best_stack: int = 0

const EXP_RANKS: Array[Dictionary] = [
	{"level": 1, "name": "Novice Stacker", "icon": "🥉", "min_exp": 0, "next_exp": 5},
	{"level": 2, "name": "Steady Builder", "icon": "🥈", "min_exp": 5, "next_exp": 15},
	{"level": 3, "name": "Tower Specialist", "icon": "🥇", "min_exp": 15, "next_exp": 30},
	{"level": 4, "name": "Sky Architect", "icon": "💎", "min_exp": 30, "next_exp": 50},
	{"level": 5, "name": "Cloud Piercer", "icon": "👑", "min_exp": 50, "next_exp": 80},
	{"level": 6, "name": "Cosmic Zenith", "icon": "🌌", "min_exp": 80, "next_exp": 120},
	{"level": 7, "name": "Dimension Shifter", "icon": "🔮", "min_exp": 120, "next_exp": 180},
	{"level": 8, "name": "Infinite Master", "icon": "🌟", "min_exp": 180, "next_exp": 999999}
]

# Campaign Mode System
const CAMPAIGN_SAVE_PATH: String = "user://campaign_data.json"
var campaign_unlocked_stage: int = 1
var campaign_completed_stages: Array = []
var active_campaign_stage_id: int = 0

static func _generate_50_campaign_stages() -> Array[Dictionary]:
	var stages: Array[Dictionary] = []
	var badges = [
		"🌱", "🌿", "🎵", "🍃", "🥉", "🌸", "🌼", "🌷", "🌹", "🥈",
		"🏗️", "🏙️", "🗼", "🦅", "🥇", "🪁", "🎈", "🌅", "🔥", "💎",
		"☁️", "🕊️", "🌈", "✨", "⚡", "🌪️", "💯", "🪐", "🔮", "👑",
		"🚀", "🛰️", "🌌", "☄️", "🌟", "🌠", "🌑", "🌕", "🌞", "🏆",
		"🌀", "💫", "💠", "🔱", "🛡️", "⚔️", "🗝️", "⏳", "👁️", "👑"
	]
	var titles = [
		"First Foundation", "Step by Step", "Rhythm Awakening", "Gentle Ascent", "Bronze Milestone",
		"Spring Momentum", "Balancing Act", "Floral Spire", "Crimson Balance", "Silver Keystone",
		"Scaffold Walker", "Skyward Metro", "Radio Tower", "Eagle's Perch", "Gold Beacon",
		"High Kite", "Atmosphere Drift", "Sunrise Spire", "Phoenix Rise", "Diamond Obelisk",
		"Cumulus Crossing", "Silver Feather", "Rainbow Bridge", "Starlight Ladder", "Thunder Strata",
		"Vortex Haven", "Centurion Peak", "Celestial Ring", "Aether Spiral", "Cloud Emperor",
		"Rocket Trajectory", "Orbital Array", "Aurora Veil", "Comet Tail", "Supernova Pillar",
		"Meteor Crossing", "Lunar Eclipse", "Full Moon Zenith", "Solar Prominence", "Cosmic Champion",
		"Dimension Warp", "Hyperdrive Spire", "Quantum Core", "Poseidon's Trident", "Aegis Pillar",
		"Blades of Time", "Key of Eternity", "Hourglass Peak", "Cosmic Eye", "Ascent to Divinity"
	]
	for i in range(50):
		var id = i + 1
		var blocks: int = 6 + int(i * 3.1)
		var combo: int = 0
		if (id % 5) == 0:
			combo = mini(int(id / 10) + 2, 5)
		elif (id % 3) == 0 and id > 10:
			combo = mini(int(id / 15) + 1, 4)
		var exp_rew: int = 2 + int(i * 0.6)
		var b = badges[i] if i < badges.size() else "⭐"
		var t = titles[i] if i < titles.size() else ("Stage " + str(id))
		var desc = "Reach %d blocks" % blocks
		if combo > 0:
			desc += " with %dx streak" % combo
		stages.append({
			"id": id,
			"title": "Stage %d: %s" % [id, t],
			"desc": desc,
			"target_blocks": blocks,
			"target_combo": combo,
			"exp_reward": exp_rew,
			"badge": b
		})
	return stages

var CAMPAIGN_STAGES: Array[Dictionary] = _generate_50_campaign_stages()
var _campaign_selected_stage_id: int = 1

var _toast_panel: PanelContainer = null
var _toast_label: Label = null
var _toast_tween: Tween = null

# Skin / palette tile refs for in-place style updates (no drawer rebuild)
var _skin_tile_btns: Array = []
var _pal_tile_btns: Array = []
var _pal_section_root: Control = null

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
	"terrazzo": preload("res://textures/skin_terrazzo.png"),
	"glass": preload("res://textures/skin_glass.png"),
	"frosted": preload("res://textures/skin_frosted.png"),
	"dusty": preload("res://textures/skin_dusty.png"),
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
		"id": "terrazzo",
		"name": "Modern Terrazzo",
		"icon": "🪨",
		"desc": "Architectural composite stone with embedded polished quartz and mineral flakes.",
		"type": "textured",
		"strength": 0.68,
		"emission": 0.0,
		"roughness": 0.36,
		"metallic": 0.04,
		"uv_scale": Vector2(0.70, 0.70)
	},
	{
		"id": "glass",
		"name": "Clear Glass",
		"icon": "🔷",
		"desc": "Ultra-smooth polished glass surface with faint diagonal specular reflection streaks.",
		"type": "textured",
		"strength": 0.60,
		"emission": 0.0,
		"roughness": 0.06,
		"metallic": 0.08,
		"uv_scale": Vector2(0.50, 0.50)
	},
	{
		"id": "frosted",
		"name": "Frosted Glass",
		"icon": "❄️",
		"desc": "Soft milky diffusion surface etched with fine crystalline micro-scratches.",
		"type": "textured",
		"strength": 0.72,
		"emission": 0.0,
		"roughness": 0.72,
		"metallic": 0.01,
		"uv_scale": Vector2(0.60, 0.60)
	},
	{
		"id": "dusty",
		"name": "Dusty Sand",
		"icon": "🏜️",
		"desc": "Warm sandy-beige surface with coarse aggregate grain and fine dust particulate speckling.",
		"type": "textured",
		"strength": 0.80,
		"emission": 0.0,
		"roughness": 0.88,
		"metallic": 0.00,
		"uv_scale": Vector2(0.75, 0.75)
	},
]
const SKIN_SAVE_PATH: String = "user://skin_data.json"
var active_skin_id: String = "classic"
var sniper_reticle_enabled: bool = false

func save_skin_data() -> void:
	var file = FileAccess.open(SKIN_SAVE_PATH, FileAccess.WRITE)
	if file:
		var data = {
			"active_skin_id": active_skin_id,
			"sniper_reticle_enabled": sniper_reticle_enabled,
			"palette_index": palette_index
		}
		file.store_string(JSON.stringify(data, "\t"))

func load_skin_data() -> void:
	if FileAccess.file_exists(SKIN_SAVE_PATH):
		var file = FileAccess.open(SKIN_SAVE_PATH, FileAccess.READ)
		if file:
			var text = file.get_as_text()
			var json = JSON.new()
			if json.parse(text) == OK and typeof(json.data) == TYPE_DICTIONARY:
				var data: Dictionary = json.data
				if data.has("active_skin_id"):
					var loaded_skin = str(data["active_skin_id"])
					for s in SKINS:
						if s["id"] == loaded_skin:
							active_skin_id = loaded_skin
							break
				if data.has("sniper_reticle_enabled"):
					sniper_reticle_enabled = bool(data["sniper_reticle_enabled"])
				if data.has("palette_index"):
					palette_index = clampi(int(data["palette_index"]), 0, PALETTES.size() - 1)

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
	for i in range(stack.size()):
		var b = stack[i]
		if is_instance_valid(b):
			if b.has_method("apply_skin"):
				b.apply_skin(skin_cfg)
			if b.has_method("set_color"):
				b.set_color(_get_box_shade(i))

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
	},
	{
		"name": "Translucent Prism",
		"mode": "rainbow",
		"is_transparent": true,
		"speed": 0.026,
		"sat": 0.62,
		"val": 0.96,
		"alpha": 0.55,
		"bg_top": Color(0.06, 0.07, 0.16),    # Dark Deep Space
		"bg_bottom": Color(0.16, 0.12, 0.26) # Translucent Aurora Violet
	},
	{
		"name": "Translucent Jelly",
		"mode": "gradient",
		"is_transparent": true,
		"colors": [
			Color(0.98, 0.28, 0.52, 0.56), # Lucid Ruby Pink
			Color(0.82, 0.35, 0.96, 0.56), # Lucid Violet Amethyst
			Color(0.30, 0.64, 0.98, 0.56), # Lucid Azure Sapphire
			Color(0.20, 0.88, 0.72, 0.56), # Lucid Emerald Jade
			Color(0.98, 0.78, 0.22, 0.56), # Lucid Citrine Topaz
			Color(0.98, 0.46, 0.28, 0.56)  # Lucid Sunset Coral
		],
		"bg_top": Color(0.07, 0.08, 0.18),    # Deep Midnight Sapphire
		"bg_bottom": Color(0.20, 0.11, 0.26) # Rich Jelly Fuchsia
	},
	{
		"name": "Frosted Crystal",
		"mode": "gradient",
		"is_transparent": true,
		"colors": [
			Color(0.96, 0.68, 0.82, 0.52), # Frosted Rose Quartz
			Color(0.80, 0.72, 0.98, 0.52), # Frosted Lavender
			Color(0.60, 0.82, 0.98, 0.52), # Frosted Glacier Blue
			Color(0.55, 0.94, 0.86, 0.52), # Frosted Aquamarine
			Color(0.96, 0.88, 0.66, 0.52)  # Frosted Soft Champagne
		],
		"bg_top": Color(0.08, 0.12, 0.20),    # Polar Slate
		"bg_bottom": Color(0.14, 0.18, 0.28) # Crystalline Blue
	},
	{
		"name": "Smoky Obsidian",
		"mode": "gradient",
		"is_transparent": true,
		"colors": [
			Color(0.36, 0.44, 0.58, 0.62), # Smoky Slate Glass
			Color(0.58, 0.42, 0.55, 0.62), # Smoky Mauve Glass
			Color(0.28, 0.52, 0.55, 0.62), # Smoky Teal Glass
			Color(0.60, 0.48, 0.36, 0.62), # Smoky Amber Topaz
			Color(0.44, 0.38, 0.55, 0.62)  # Smoky Dusk Glass
		],
		"bg_top": Color(0.05, 0.06, 0.10),    # Obsidian Void
		"bg_bottom": Color(0.12, 0.13, 0.19) # Smoky Dark Veil
	}
]
var palette_index: int = 0
var current_palette_start_hue: float = 0.58

func _ready() -> void:
	_setup_desktop_window_size()
	get_tree().root.size_changed.connect(_on_window_resized)
	_on_window_resized()

	load_high_score()
	load_exp_data()
	load_campaign_data()
	load_skin_data()
	_setup_lighting_and_env()
	_setup_gradient_background()
	_create_pedestal()
	_setup_realistic_fog_sheets()
	base_camera_pivot_y = camera_pivot.position.y
	target_camera_y = base_camera_pivot_y
	target_camera_x = camera_pivot.position.x
	target_camera_z = camera_pivot.position.z
	
	slider.box_released.connect(_on_box_released)
	if slider.has_method("set_sniper_reticle_enabled"):
		slider.set_sniper_reticle_enabled(sniper_reticle_enabled)
	sound_btn.pressed.connect(_on_sound_btn_pressed)
	if is_instance_valid(play_close_btn):
		play_close_btn.pressed.connect(_on_play_close_pressed)
		play_close_btn.visible = false
	$UI/GameOverPanel/VBox/RestartBtn.pressed.connect(restart_game)
	home_btn.pressed.connect(show_main_menu)
	if is_instance_valid(game_over_close_btn):
		game_over_close_btn.pressed.connect(_on_game_over_close_pressed)
		game_over_close_btn.visible = false
	
	_setup_exp_badge()
	_setup_ribbon_listeners()
	_set_active_tab("home")
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
	rim_mat.roughness = 0.50
	rim_mat.metallic = 0.10
	rim_mat.emission_enabled = false
	pedestal_rim.material_override = rim_mat
	pedestal_rim.position = Vector3(0, 0.0, 0)
	add_child(pedestal_rim)
	
	_update_pedestal_color(false)
	
	# Soft ethereal mist ring around the lower column
	_setup_pedestal_mist()

# Sets the base pedestal and rim to be distinctly darker than the cube
func _update_pedestal_color(animate: bool = false) -> void:
	var first_color = _get_box_shade(0)
	# The base pedestal top is significantly darker than the cube (solid, grounded foundation)
	var base_dark = first_color.darkened(0.55)
	base_dark.a = 1.0
	# Rim accent is also noticeably darker than the cube
	var rim_dark = first_color.darkened(0.38)
	rim_dark.a = 1.0
	
	if is_instance_valid(pedestal_mat):
		if animate and bg_tween:
			var cur_top = pedestal_mat.get_shader_parameter("top_color")
			if cur_top == null:
				cur_top = base_dark
			bg_tween.tween_method(func(c: Color):
				if is_instance_valid(pedestal_mat):
					pedestal_mat.set_shader_parameter("top_color", c)
			, cur_top, base_dark, 0.7)
		else:
			pedestal_mat.set_shader_parameter("top_color", base_dark)
	
	if is_instance_valid(pedestal_rim) and pedestal_rim.material_override:
		var rm = pedestal_rim.material_override as StandardMaterial3D
		if animate and bg_tween:
			bg_tween.tween_property(rm, "albedo_color", rim_dark, 0.7)
		else:
			rm.albedo_color = rim_dark
		rm.emission_enabled = false
		rm.roughness = 0.50
		rm.metallic = 0.10

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

func _get_today_date_str() -> String:
	var d = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]

func get_current_rank_info() -> Dictionary:
	var rank = EXP_RANKS[0]
	for r in EXP_RANKS:
		if total_exp >= r["min_exp"]:
			rank = r
		else:
			break
	return rank

func load_exp_data() -> void:
	var today = _get_today_date_str()
	if FileAccess.file_exists(EXP_SAVE_PATH):
		var file = FileAccess.open(EXP_SAVE_PATH, FileAccess.READ)
		if file:
			var text = file.get_as_text()
			var json = JSON.new()
			if json.parse(text) == OK and typeof(json.data) == TYPE_DICTIONARY:
				var data: Dictionary = json.data
				total_exp = int(data.get("total_exp", 0))
				exp_today_date = str(data.get("today_date", ""))
				login_claimed_date = str(data.get("login_claimed_date", ""))
				perfect_3_claimed_date = str(data.get("perfect_3_claimed_date", ""))
				stack_50_claimed_date = str(data.get("stack_50_claimed_date", ""))
				stack_100_claimed_date = str(data.get("stack_100_claimed_date", ""))
				daily_best_combo = int(data.get("daily_best_combo", 0))
				daily_best_stack = int(data.get("daily_best_stack", 0))
	
	if exp_today_date != today:
		exp_today_date = today
		daily_best_combo = 0
		daily_best_stack = 0
		save_exp_data()
	
	_update_exp_badge(false)

func _setup_exp_badge() -> void:
	if not is_instance_valid(exp_badge_btn):
		return
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.16, 0.85)
	style.border_color = Color(1.0, 0.85, 0.35, 0.40)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.set_corner_radius_all(16)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	
	var style_hover = style.duplicate() as StyleBoxFlat
	style_hover.bg_color = Color(0.14, 0.18, 0.28, 0.95)
	style_hover.border_color = Color(1.0, 0.85, 0.35, 0.8)
	
	exp_badge_btn.add_theme_stylebox_override("normal", style)
	exp_badge_btn.add_theme_stylebox_override("hover", style_hover)
	exp_badge_btn.add_theme_stylebox_override("pressed", style_hover)
	exp_badge_btn.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35, 1.0))
	exp_badge_btn.add_theme_font_size_override("font_size", 14)
	
	exp_badge_btn.pressed.connect(func():
		sound_mgr.play_click()
		if state == GameState.MENU:
			_set_active_tab("exp")
			_open_exp_drawer()
		else:
			var r = get_current_rank_info()
			_show_task_toast("⭐ %d Total EXP • %s (Lvl %d)" % [total_exp, r["name"], r["level"]])
	)
	
	_update_exp_badge(false)

func _update_exp_badge(animate: bool = false) -> void:
	if not is_instance_valid(exp_badge_btn):
		return
	exp_badge_btn.text = "⭐ %d EXP" % total_exp
	if animate:
		var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		exp_badge_btn.pivot_offset = exp_badge_btn.size * 0.5
		exp_badge_btn.scale = Vector2(1.25, 1.25)
		tween.tween_property(exp_badge_btn, "scale", Vector2.ONE, 0.25)

func save_exp_data() -> void:
	var file = FileAccess.open(EXP_SAVE_PATH, FileAccess.WRITE)
	if file:
		var data = {
			"total_exp": total_exp,
			"today_date": exp_today_date,
			"login_claimed_date": login_claimed_date,
			"perfect_3_claimed_date": perfect_3_claimed_date,
			"stack_50_claimed_date": stack_50_claimed_date,
			"stack_100_claimed_date": stack_100_claimed_date,
			"daily_best_combo": daily_best_combo,
			"daily_best_stack": daily_best_stack
		}
		file.store_string(JSON.stringify(data, "\t"))

func claim_task_exp(task_id: String) -> void:
	var today = _get_today_date_str()
	var earned: int = 0
	
	match task_id:
		"login":
			if login_claimed_date != today:
				login_claimed_date = today
				earned = 1
		"perfect_3":
			if perfect_3_claimed_date != today and daily_best_combo >= 3:
				perfect_3_claimed_date = today
				earned = 2
		"stack_50":
			if stack_50_claimed_date != today and daily_best_stack >= 50:
				stack_50_claimed_date = today
				earned = 1
		"stack_100":
			if stack_100_claimed_date != today and daily_best_stack >= 100:
				stack_100_claimed_date = today
				earned = 2
	
	if earned > 0:
		total_exp += earned
		save_exp_data()
		_update_exp_badge(true)
		sound_mgr.play_perfect(4)
		_show_task_toast("⭐ +%d EXP Claimed!" % earned)
		_open_exp_drawer()

func claim_all_available_exp() -> void:
	var today = _get_today_date_str()
	var earned: int = 0
	if login_claimed_date != today:
		login_claimed_date = today
		earned += 1
	if perfect_3_claimed_date != today and daily_best_combo >= 3:
		perfect_3_claimed_date = today
		earned += 2
	if stack_50_claimed_date != today and daily_best_stack >= 50:
		stack_50_claimed_date = today
		earned += 1
	if stack_100_claimed_date != today and daily_best_stack >= 100:
		stack_100_claimed_date = today
		earned += 2
	
	if earned > 0:
		total_exp += earned
		save_exp_data()
		_update_exp_badge(true)
		sound_mgr.play_perfect(5)
		_show_task_toast("🎉 +%d Total EXP Claimed!" % earned)
		_open_exp_drawer()

func _show_task_toast(message: String) -> void:
	if not _toast_panel or not is_instance_valid(_toast_panel):
		_toast_panel = PanelContainer.new()
		_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_toast_panel.anchors_preset = Control.PRESET_CENTER_TOP
		_toast_panel.anchor_left = 0.5
		_toast_panel.anchor_right = 0.5
		_toast_panel.anchor_top = 0.0
		_toast_panel.anchor_bottom = 0.0
		_toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_toast_panel.offset_top = 80.0
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.10, 0.16, 0.95)
		style.border_color = Color(1.0, 0.82, 0.30, 0.8)
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
		style.set_corner_radius_all(14)
		style.content_margin_left = 18
		style.content_margin_right = 18
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		_toast_panel.add_theme_stylebox_override("panel", style)
		
		_toast_label = Label.new()
		_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_toast_label.add_theme_font_size_override("font_size", 15)
		_toast_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.35, 1.0))
		_toast_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast_panel.add_child(_toast_label)
		ui_layer.add_child(_toast_panel)
	
	_toast_label.text = message
	_toast_panel.visible = true
	_toast_panel.modulate.a = 0.0
	
	if _toast_tween:
		_toast_tween.kill()
	
	_toast_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.25)
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.35)
	_toast_tween.tween_callback(func(): _toast_panel.visible = false)

func is_stage_unlocked(stage_id: int) -> bool:
	if stage_id <= 1:
		return true
	if stage_id <= campaign_unlocked_stage:
		return true
	for c in campaign_completed_stages:
		if int(c) >= stage_id - 1:
			return true
	return false

func is_stage_cleared(stage_id: int) -> bool:
	for c in campaign_completed_stages:
		if int(c) == stage_id:
			return true
	return false

func load_campaign_data() -> void:
	if FileAccess.file_exists(CAMPAIGN_SAVE_PATH):
		var file = FileAccess.open(CAMPAIGN_SAVE_PATH, FileAccess.READ)
		if file:
			var text = file.get_as_text()
			var json = JSON.new()
			if json.parse(text) == OK and typeof(json.data) == TYPE_DICTIONARY:
				var data: Dictionary = json.data
				campaign_unlocked_stage = int(data.get("unlocked_stage", 1))
				var raw_stages = data.get("completed_stages", [])
				campaign_completed_stages.clear()
				for s in raw_stages:
					var sid = int(s)
					if sid > 0 and not campaign_completed_stages.has(sid):
						campaign_completed_stages.append(sid)
						campaign_unlocked_stage = maxi(campaign_unlocked_stage, sid + 1)
	
	campaign_unlocked_stage = clampi(campaign_unlocked_stage, 1, CAMPAIGN_STAGES.size())

func save_campaign_data() -> void:
	for c in campaign_completed_stages:
		campaign_unlocked_stage = maxi(campaign_unlocked_stage, int(c) + 1)
	campaign_unlocked_stage = clampi(campaign_unlocked_stage, 1, CAMPAIGN_STAGES.size())
	
	var file = FileAccess.open(CAMPAIGN_SAVE_PATH, FileAccess.WRITE)
	if file:
		var data = {
			"unlocked_stage": campaign_unlocked_stage,
			"completed_stages": campaign_completed_stages
		}
		file.store_string(JSON.stringify(data, "\t"))

func _on_play_close_pressed() -> void:
	sound_mgr.play_click()
	_stop_play_again_pulse()
	if is_instance_valid(play_close_btn):
		play_close_btn.visible = false
	if is_instance_valid(game_over_close_btn):
		game_over_close_btn.visible = false
	show_main_menu()

func _on_game_over_close_pressed() -> void:
	sound_mgr.play_click()
	_stop_play_again_pulse()
	if is_instance_valid(game_over_close_btn):
		game_over_close_btn.visible = false
	show_main_menu()

func show_main_menu() -> void:
	state = GameState.MENU
	if campaign_unlocked_stage > 0:
		_campaign_selected_stage_id = clampi(campaign_unlocked_stage, 1, CAMPAIGN_STAGES.size())
	active_campaign_stage_id = 0
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
	if is_instance_valid(game_over_close_btn):
		game_over_close_btn.visible = false
	if is_instance_valid(play_close_btn):
		play_close_btn.visible = false
	
	# Show Main Menu
	main_menu.visible = true
	main_menu.modulate.a = 1.0
	menu_best_score.text = "BEST: " + str(high_score)
	
	# Close any open drawer and reset tab to home
	if _restart_tween:
		_restart_tween.kill()
		_restart_tween = null
	_is_restarting = false
	if is_instance_valid(base_pedestal):
		base_pedestal.position.y = -12.0
	if is_instance_valid(pedestal_rim):
		pedestal_rim.position.y = 0.0
	if is_instance_valid(pedestal_mist_particles):
		pedestal_mist_particles.position.y = -6.0
	_stop_play_again_pulse()
	_close_drawer(true)
	_set_active_tab("home")
	
	# Start pulsing tap to play button
	_start_tap_pulse()
	
	# Setup attractive idling slider box over pedestal
	current_top_y = 0.0
	current_target_pos = Vector3.ZERO
	slider.set_target_level(current_top_y, current_target_pos, 0)
	slider.speed_multiplier = 0.85 * challenge_speed_multiplier
	_update_pedestal_color(false)
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
	
	_close_drawer(true)
	
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
	if is_instance_valid(play_close_btn):
		play_close_btn.visible = true
	if active_campaign_stage_id > 0:
		for st in CAMPAIGN_STAGES:
			if st["id"] == active_campaign_stage_id:
				prompt_label.text = "%s: TARGET %d BLOCKS" % [st["title"].to_upper(), st["target_blocks"]]
				break
	elif not OS.has_feature("android") and not OS.has_feature("mobile"):
		prompt_label.text = "CLICK OR PRESS SPACE TO DROP"
	else:
		prompt_label.text = "TAP SCREEN TO DROP"
	
	slider.speed_multiplier = 1.0 * challenge_speed_multiplier
	if is_instance_valid(active_box):
		active_box.landed.connect(_on_box_landed)

func _setup_ribbon_listeners() -> void:
	tap_to_play_btn.pressed.connect(start_game_from_menu)
	
	for b in [btn_home, btn_skin, btn_challenge, btn_campaign, btn_levels]:
		if is_instance_valid(b):
			b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
			b.focus_mode = Control.FOCUS_NONE
	
	btn_home.pressed.connect(func():
		sound_mgr.play_click()
		_close_drawer()
		_set_active_tab("home")
	)
	btn_skin.pressed.connect(func():
		if drawer_modal.visible and active_ribbon_tab == "skin":
			return
		sound_mgr.play_click()
		_set_active_tab("skin")
		_open_skins_drawer()
	)
	btn_challenge.pressed.connect(func():
		if drawer_modal.visible and active_ribbon_tab == "challenge":
			return
		sound_mgr.play_click()
		_set_active_tab("challenge")
		_open_challenge_drawer()
	)
	btn_campaign.pressed.connect(func():
		if drawer_modal.visible and active_ribbon_tab == "campaign":
			return
		sound_mgr.play_click()
		_set_active_tab("campaign")
		_open_campaign_drawer()
	)
	btn_levels.pressed.connect(func():
		if drawer_modal.visible and active_ribbon_tab == "exp":
			return
		sound_mgr.play_click()
		_set_active_tab("exp")
		_open_exp_drawer()
	)
	close_drawer_btn.pressed.connect(func():
		sound_mgr.play_click()
		_close_drawer()
		_set_active_tab("home")
	)

func _set_active_tab(tab_name: String) -> void:
	if tab_name == "levels":
		tab_name = "exp"
	active_ribbon_tab = tab_name
	
	# Simple square white box style for the active ribbon tab (stays permanently on clicked tab)
	var active_style = StyleBoxFlat.new()
	active_style.bg_color = Color(1.0, 1.0, 1.0, 0.16)
	active_style.border_width_left = 2
	active_style.border_width_top = 2
	active_style.border_width_right = 2
	active_style.border_width_bottom = 2
	active_style.border_color = Color(1.0, 1.0, 1.0, 1.0)
	active_style.corner_radius_top_left = 4
	active_style.corner_radius_top_right = 4
	active_style.corner_radius_bottom_right = 4
	active_style.corner_radius_bottom_left = 4
	
	# Inactive tab: completely flat, muted
	var inactive_style = StyleBoxEmpty.new()
	
	var tabs = {
		"skin": btn_skin,
		"challenge": btn_challenge,
		"home": btn_home,
		"campaign": btn_campaign,
		"exp": btn_levels
	}
	
	for key in tabs.keys():
		var btn: Button = tabs[key]
		if not is_instance_valid(btn):
			continue
		var icon = btn.get_node_or_null("VBox/Icon") as TextureRect
		var lbl = btn.get_node_or_null("VBox/Label") as Label
		
		# All ribbon icons remain pure white
		if icon:
			icon.modulate = Color(1.0, 1.0, 1.0, 1.0)
		
		if key == tab_name:
			btn.flat = false
			btn.add_theme_stylebox_override("normal", active_style)
			btn.add_theme_stylebox_override("hover", active_style)
			btn.add_theme_stylebox_override("pressed", active_style)
			btn.add_theme_stylebox_override("focus", active_style)
			btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
			if lbl:
				lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		else:
			btn.flat = true
			btn.add_theme_stylebox_override("normal", inactive_style)
			btn.add_theme_stylebox_override("hover", inactive_style)
			btn.add_theme_stylebox_override("pressed", inactive_style)
			btn.add_theme_stylebox_override("focus", inactive_style)
			btn.add_theme_color_override("font_color", Color(0.58, 0.65, 0.80, 0.75))
			if lbl:
				lbl.add_theme_color_override("font_color", Color(0.58, 0.65, 0.80, 0.75))

func _open_drawer(title_text: String, is_fullscreen: bool = false) -> void:
	if drawer_tween:
		drawer_tween.kill()
		drawer_tween = null
	
	drawer_title.text = title_text
	
	if is_fullscreen:
		drawer_modal.anchor_left = 0.0
		drawer_modal.anchor_right = 1.0
		drawer_modal.anchor_top = 0.0
		drawer_modal.anchor_bottom = 1.0
		drawer_modal.offset_left = 0.0
		drawer_modal.offset_top = 0.0
		drawer_modal.offset_right = 0.0
		drawer_modal.offset_bottom = 0.0
		if is_instance_valid(drawer_scroll):
			drawer_scroll.custom_minimum_size = Vector2(0, 0)
			drawer_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.07, 0.08, 0.13, 0.99)
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 28
		sb.content_margin_bottom = 20
		sb.set_border_width_all(0)
		sb.set_corner_radius_all(0)
		drawer_modal.add_theme_stylebox_override("panel", sb)
	else:
		drawer_modal.anchor_left = 0.0
		drawer_modal.anchor_right = 1.0
		drawer_modal.anchor_top = 1.0
		drawer_modal.anchor_bottom = 1.0
		drawer_modal.offset_left = 0.0
		drawer_modal.offset_top = -488.0
		drawer_modal.offset_right = 0.0
		drawer_modal.offset_bottom = -88.0
		if is_instance_valid(drawer_scroll):
			drawer_scroll.custom_minimum_size = Vector2(0, 370)
			drawer_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
			drawer_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.07, 0.08, 0.13, 0.98)
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 12
		sb.content_margin_bottom = 12
		sb.border_width_top = 1
		sb.border_color = Color(1.0, 1.0, 1.0, 0.07)
		sb.corner_radius_top_left = 12
		sb.corner_radius_top_right = 12
		drawer_modal.add_theme_stylebox_override("panel", sb)
	
	for child in drawer_content.get_children():
		drawer_content.remove_child(child)
		child.queue_free()
	
	if is_instance_valid(drawer_scroll):
		drawer_scroll.scroll_vertical = 0
	_scroll_velocity_y = 0.0
	_scroll_is_dragging = false
	_scroll_touch_active = false
	
	var was_already_open = drawer_modal.visible and drawer_modal.modulate.a > 0.05
	drawer_modal.visible = true
	
	if not was_already_open:
		drawer_modal.modulate.a = 0.0
		drawer_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		drawer_tween.tween_property(drawer_modal, "modulate:a", 1.0, 0.20)
	else:
		drawer_modal.modulate.a = 1.0

func _close_drawer(immediate: bool = false) -> void:
	if drawer_tween:
		drawer_tween.kill()
		drawer_tween = null
	
	_scroll_velocity_y = 0.0
	_scroll_is_dragging = false
	_scroll_touch_active = false
	
	if not drawer_modal.visible:
		return
	
	if immediate:
		drawer_modal.visible = false
		drawer_modal.modulate.a = 0.0
		return
	
	drawer_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	drawer_tween.tween_property(drawer_modal, "modulate:a", 0.0, 0.14)
	drawer_tween.tween_callback(func():
		drawer_modal.visible = false
	)

var _scroll_is_mouse: bool = false

func _get_max_drawer_scroll() -> int:
	if not is_instance_valid(drawer_scroll):
		return 0
	var v_bar = drawer_scroll.get_v_scroll_bar()
	var max_s = 0
	if is_instance_valid(v_bar) and v_bar.max_value > 0.0:
		max_s = int(max(0.0, v_bar.max_value - v_bar.page))
	if max_s <= 0 and is_instance_valid(drawer_content):
		var min_h = drawer_content.get_combined_minimum_size().y
		max_s = int(max(0.0, min_h - drawer_scroll.size.y))
	if max_s <= 0 and is_instance_valid(drawer_content):
		max_s = int(max(0.0, drawer_content.size.y - drawer_scroll.size.y))
	return max_s

func _is_scroll_dragging() -> bool:
	if _scroll_is_dragging:
		return true
	if Time.get_ticks_msec() - _scroll_last_drag_time < 250:
		return true
	return false

func _input(event: InputEvent) -> void:
	if not is_instance_valid(drawer_modal) or not drawer_modal.visible or not is_instance_valid(drawer_scroll):
		_scroll_touch_active = false
		_scroll_is_dragging = false
		return
	
	var drawer_rect: Rect2 = drawer_modal.get_global_rect()
	
	if event is InputEventScreenTouch:
		if event.pressed:
			if drawer_rect.has_point(event.position):
				_scroll_touch_active = true
				_scroll_touch_index = event.index
				_scroll_is_mouse = false
				_scroll_start_y = event.position.y
				_scroll_start_val = drawer_scroll.scroll_vertical
				_scroll_is_dragging = false
				_scroll_velocity_y = 0.0
				_scroll_last_pos_y = event.position.y
				_scroll_last_pos_time = Time.get_ticks_msec()
		else:
			if _scroll_touch_active and not _scroll_is_mouse and (event.index == _scroll_touch_index or _scroll_touch_index == -1):
				_scroll_touch_active = false
				if _scroll_is_dragging:
					_scroll_last_drag_time = Time.get_ticks_msec()
					get_viewport().set_input_as_handled()
	
	elif event is InputEventScreenDrag:
		if _scroll_touch_active and not _scroll_is_mouse:
			var dy = event.position.y - _scroll_start_y
			if not _scroll_is_dragging and abs(dy) > 4.0:
				_scroll_is_dragging = true
			if _scroll_is_dragging:
				var max_scroll = _get_max_drawer_scroll()
				drawer_scroll.scroll_vertical = clampi(int(round(_scroll_start_val - dy)), 0, max_scroll)
				var now = Time.get_ticks_msec()
				var dt = float(now - _scroll_last_pos_time) / 1000.0
				if dt > 0.002:
					var step_vel = (event.position.y - _scroll_last_pos_y) / dt
					_scroll_velocity_y = lerp(_scroll_velocity_y, step_vel, 0.50)
				_scroll_last_pos_y = event.position.y
				_scroll_last_pos_time = now
				get_viewport().set_input_as_handled()
	
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Never allow emulated mouse events to clobber real touch tracking on mobile
				if not _scroll_touch_active and drawer_rect.has_point(event.position):
					_scroll_touch_active = true
					_scroll_touch_index = -1
					_scroll_is_mouse = true
					_scroll_start_y = event.position.y
					_scroll_start_val = drawer_scroll.scroll_vertical
					_scroll_is_dragging = false
					_scroll_velocity_y = 0.0
					_scroll_last_pos_y = event.position.y
					_scroll_last_pos_time = Time.get_ticks_msec()
			else:
				if _scroll_touch_active and _scroll_is_mouse:
					_scroll_touch_active = false
					if _scroll_is_dragging:
						_scroll_last_drag_time = Time.get_ticks_msec()
						get_viewport().set_input_as_handled()
	
	elif event is InputEventMouseMotion:
		if _scroll_touch_active and _scroll_is_mouse and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			var dy = event.position.y - _scroll_start_y
			if not _scroll_is_dragging and abs(dy) > 4.0:
				_scroll_is_dragging = true
			if _scroll_is_dragging:
				var max_scroll = _get_max_drawer_scroll()
				drawer_scroll.scroll_vertical = clampi(int(round(_scroll_start_val - dy)), 0, max_scroll)
				var now = Time.get_ticks_msec()
				var dt = float(now - _scroll_last_pos_time) / 1000.0
				if dt > 0.002:
					var step_vel = (event.position.y - _scroll_last_pos_y) / dt
					_scroll_velocity_y = lerp(_scroll_velocity_y, step_vel, 0.50)
				_scroll_last_pos_y = event.position.y
				_scroll_last_pos_time = now
				get_viewport().set_input_as_handled()


func _create_card_container() -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.11, 0.17, 0.90)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _create_card_button(btn_text: String, is_active: bool) -> Button:
	var btn = Button.new()
	btn.text = btn_text
	btn.custom_minimum_size = Vector2(0, 34)
	btn.add_theme_font_size_override("font_size", 13)
	var btn_style = StyleBoxFlat.new()
	btn_style.set_corner_radius_all(5)
	if is_active:
		btn_style.bg_color = Color(0.14, 0.58, 0.40, 0.95)
		btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	else:
		btn_style.bg_color = Color(0.16, 0.36, 0.70, 0.85)
		btn.add_theme_color_override("font_color", Color(0.88, 0.92, 1, 1))
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.add_theme_stylebox_override("hover", btn_style)
	btn.add_theme_stylebox_override("pressed", btn_style)
	return btn

func _make_tile_style(selected: bool, corner: int = 4) -> StyleBoxFlat:
	var st = StyleBoxFlat.new()
	st.set_corner_radius_all(corner)
	st.content_margin_left = 6
	st.content_margin_right = 6
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	if selected:
		# Exact white square box selection matching ribbon tab
		st.bg_color = Color(1.0, 1.0, 1.0, 0.16)
		st.set_border_width_all(2)
		st.border_color = Color(1.0, 1.0, 1.0, 1.0)
	else:
		st.bg_color = Color(0.10, 0.13, 0.20, 0.90)
		st.set_border_width_all(1)
		st.border_color = Color(1.0, 1.0, 1.0, 0.22)
	return st

func _create_selection_square() -> Control:
	var container = CenterContainer.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.custom_minimum_size = Vector2(0, 10)
	
	var sq = Panel.new()
	sq.custom_minimum_size = Vector2(8, 8)
	sq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st = StyleBoxFlat.new()
	st.bg_color = Color(1.0, 1.0, 1.0, 1.0)
	st.set_corner_radius_all(1)
	sq.add_theme_stylebox_override("panel", st)
	container.add_child(sq)
	return container

func _refresh_skin_tiles() -> void:
	for i in _skin_tile_btns.size():
		var btn: Button = _skin_tile_btns[i]
		if not is_instance_valid(btn):
			continue
		var skin_id: String = SKINS[i]["id"]
		var sel = (active_skin_id == skin_id)
		btn.flat = false
		btn.focus_mode = Control.FOCUS_NONE
		var st = _make_tile_style(sel, 4)
		var st_h = st.duplicate() as StyleBoxFlat
		st_h.bg_color = st.bg_color.lightened(0.06)
		btn.add_theme_stylebox_override("normal", st)
		btn.add_theme_stylebox_override("hover", st_h)
		btn.add_theme_stylebox_override("pressed", st)
		btn.add_theme_stylebox_override("focus", st)
		# Update name label color (child[0]=icon, child[1]=name_lbl)
		var inner = btn.get_child(0)
		if inner and inner.get_child_count() >= 2:
			var nlbl = inner.get_child(1) as Label
			if nlbl:
				nlbl.add_theme_color_override("font_color",
					Color(0.80, 0.86, 1.0, 0.95) if sel else Color(0.58, 0.65, 0.80, 0.80))
			# Show/hide white square badge (child index 2 when equipped)
			if sel and inner.get_child_count() < 3:
				var badge = _create_selection_square()
				inner.add_child(badge)
			elif not sel and inner.get_child_count() >= 3:
				inner.get_child(2).queue_free()
	# Palette section is always visible for all skins
	if is_instance_valid(_pal_section_root):
		_pal_section_root.visible = true

func _refresh_pal_tiles() -> void:
	for i in _pal_tile_btns.size():
		var btn: Button = _pal_tile_btns[i]
		if not is_instance_valid(btn):
			continue
		var sel = (i == palette_index)
		btn.flat = false
		btn.focus_mode = Control.FOCUS_NONE
		var st = _make_tile_style(sel, 4)
		var st_h = st.duplicate() as StyleBoxFlat
		st_h.bg_color = st.bg_color.lightened(0.06)
		btn.add_theme_stylebox_override("normal", st)
		btn.add_theme_stylebox_override("hover", st_h)
		btn.add_theme_stylebox_override("pressed", st)
		btn.add_theme_stylebox_override("focus", st)
		# Update name label color (p_inner child[0]=swatch_row, [1]=p_name)
		var p_inner = btn.get_child(0)
		if p_inner and p_inner.get_child_count() >= 2:
			var pnlbl = p_inner.get_child(1) as Label
			if pnlbl:
				pnlbl.add_theme_color_override("font_color",
					Color(0.80, 0.86, 1.0, 0.95) if sel else Color(0.58, 0.65, 0.80, 0.80))
			# Show/hide white square badge (child index 2)
			if sel and p_inner.get_child_count() < 3:
				var p_check = _create_selection_square()
				p_inner.add_child(p_check)
			elif not sel and p_inner.get_child_count() >= 3:
				p_inner.get_child(2).queue_free()

func _open_skins_drawer() -> void:
	_open_drawer("SKINS")
	_skin_tile_btns.clear()
	_pal_tile_btns.clear()
	_pal_section_root = null
	
	# --- ALL SKINS GRID (3 columns of square tiles) ---
	var skins_grid = GridContainer.new()
	skins_grid.columns = 3
	skins_grid.add_theme_constant_override("h_separation", 8)
	skins_grid.add_theme_constant_override("v_separation", 8)
	skins_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drawer_content.add_child(skins_grid)
	
	for s in SKINS:
		var is_equipped = (active_skin_id == s["id"])
		var tile_btn = Button.new()
		tile_btn.flat = false
		tile_btn.focus_mode = Control.FOCUS_NONE
		tile_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile_btn.custom_minimum_size = Vector2(0, 96)
		
		var tile_style = _make_tile_style(is_equipped, 4)
		var tile_hover = tile_style.duplicate() as StyleBoxFlat
		tile_hover.bg_color = tile_style.bg_color.lightened(0.06)
		tile_btn.add_theme_stylebox_override("normal", tile_style)
		tile_btn.add_theme_stylebox_override("hover", tile_hover)
		tile_btn.add_theme_stylebox_override("pressed", tile_style)
		tile_btn.add_theme_stylebox_override("focus", tile_style)
		
		# Inner VBox: icon + name (+ badge if equipped)
		var inner = VBoxContainer.new()
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.add_theme_constant_override("separation", 3)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tile_btn.add_child(inner)
		
		var icon_lbl = Label.new()
		icon_lbl.text = s["icon"]
		icon_lbl.add_theme_font_size_override("font_size", 30)
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(icon_lbl)
		
		var name_lbl = Label.new()
		name_lbl.text = s["name"].to_upper()
		name_lbl.add_theme_font_size_override("font_size", 9)
		name_lbl.add_theme_color_override("font_color",
			Color(0.80, 0.86, 1.0, 0.95) if is_equipped else Color(0.58, 0.65, 0.80, 0.80))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(name_lbl)
		
		if is_equipped:
			var badge = _create_selection_square()
			inner.add_child(badge)
		
		# Connect equip action — update in-place, no drawer rebuild
		var skin_id = s["id"]
		tile_btn.pressed.connect(func():
			if _is_scroll_dragging():
				return
			if active_skin_id == skin_id:
				return
			active_skin_id = skin_id
			sound_mgr.play_click()
			_update_active_skins_in_scene()
			_refresh_skin_tiles()
			save_skin_data()
		)
		_skin_tile_btns.append(tile_btn)
		skins_grid.add_child(tile_btn)
	
	# --- GUIDE MESH ACCESSORY: 2 OPTIONS (NONE, SNIPER POINTER) ---
	var reticle_section = VBoxContainer.new()
	reticle_section.add_theme_constant_override("separation", 6)
	reticle_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drawer_content.add_child(reticle_section)
	
	var r_spacer = Control.new()
	r_spacer.custom_minimum_size = Vector2(0, 4)
	reticle_section.add_child(r_spacer)
	
	var r_header = Label.new()
	r_header.text = "GUIDE MESH ACCESSORY"
	r_header.add_theme_font_size_override("font_size", 12)
	r_header.add_theme_color_override("font_color", Color(0.55, 0.64, 0.82, 0.80))
	reticle_section.add_child(r_header)
	
	var acc_grid = GridContainer.new()
	acc_grid.columns = 2
	acc_grid.add_theme_constant_override("h_separation", 8)
	acc_grid.add_theme_constant_override("v_separation", 8)
	acc_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reticle_section.add_child(acc_grid)
	
	# Option 1: None
	var btn_none = Button.new()
	btn_none.flat = false
	btn_none.focus_mode = Control.FOCUS_NONE
	btn_none.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_none.custom_minimum_size = Vector2(0, 78)
	acc_grid.add_child(btn_none)
	
	var inner_none = VBoxContainer.new()
	inner_none.alignment = BoxContainer.ALIGNMENT_CENTER
	inner_none.add_theme_constant_override("separation", 2)
	inner_none.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_none.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn_none.add_child(inner_none)
	
	var none_icon = Label.new()
	none_icon.text = "🚫"
	none_icon.add_theme_font_size_override("font_size", 22)
	none_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	none_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_none.add_child(none_icon)
	
	var none_title = Label.new()
	none_title.text = "NONE"
	none_title.add_theme_font_size_override("font_size", 10)
	none_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	none_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_none.add_child(none_title)
	
	var none_desc = Label.new()
	none_desc.text = "Standard Guide"
	none_desc.add_theme_font_size_override("font_size", 8)
	none_desc.add_theme_color_override("font_color", Color(0.58, 0.65, 0.80, 0.70))
	none_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	none_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_none.add_child(none_desc)
	
	var none_badge = _create_selection_square()
	inner_none.add_child(none_badge)
	
	# Option 2: Sniper Pointer
	var btn_sniper = Button.new()
	btn_sniper.flat = false
	btn_sniper.focus_mode = Control.FOCUS_NONE
	btn_sniper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_sniper.custom_minimum_size = Vector2(0, 78)
	acc_grid.add_child(btn_sniper)
	
	var inner_sniper = VBoxContainer.new()
	inner_sniper.alignment = BoxContainer.ALIGNMENT_CENTER
	inner_sniper.add_theme_constant_override("separation", 2)
	inner_sniper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_sniper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn_sniper.add_child(inner_sniper)
	
	var sniper_icon = Label.new()
	sniper_icon.text = "🎯"
	sniper_icon.add_theme_font_size_override("font_size", 22)
	sniper_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sniper_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_sniper.add_child(sniper_icon)
	
	var sniper_title = Label.new()
	sniper_title.text = "SNIPER POINTER"
	sniper_title.add_theme_font_size_override("font_size", 10)
	sniper_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sniper_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_sniper.add_child(sniper_title)
	
	var sniper_desc = Label.new()
	sniper_desc.text = "Tactical Reticle"
	sniper_desc.add_theme_font_size_override("font_size", 8)
	sniper_desc.add_theme_color_override("font_color", Color(0.58, 0.65, 0.80, 0.70))
	sniper_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sniper_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_sniper.add_child(sniper_desc)
	
	var sniper_badge = _create_selection_square()
	inner_sniper.add_child(sniper_badge)
	
	var update_reticle_options_ui = func():
		var is_none = not sniper_reticle_enabled
		var is_sniper = sniper_reticle_enabled
		
		# Style None button
		var st_n = _make_tile_style(is_none, 4)
		var st_nh = st_n.duplicate() as StyleBoxFlat
		st_nh.bg_color = st_n.bg_color.lightened(0.06)
		btn_none.add_theme_stylebox_override("normal", st_n)
		btn_none.add_theme_stylebox_override("hover", st_nh)
		btn_none.add_theme_stylebox_override("pressed", st_n)
		btn_none.add_theme_stylebox_override("focus", st_n)
		none_title.add_theme_color_override("font_color",
			Color(0.92, 0.94, 0.98, 1.0) if is_none else Color(0.58, 0.65, 0.80, 0.80))
		none_badge.visible = is_none
		
		# Style Sniper button
		var st_s = _make_tile_style(is_sniper, 4)
		var st_sh = st_s.duplicate() as StyleBoxFlat
		st_sh.bg_color = st_s.bg_color.lightened(0.06)
		btn_sniper.add_theme_stylebox_override("normal", st_s)
		btn_sniper.add_theme_stylebox_override("hover", st_sh)
		btn_sniper.add_theme_stylebox_override("pressed", st_s)
		btn_sniper.add_theme_stylebox_override("focus", st_s)
		sniper_title.add_theme_color_override("font_color",
			Color(0.92, 0.94, 0.98, 1.0) if is_sniper else Color(0.58, 0.65, 0.80, 0.80))
		sniper_badge.visible = is_sniper
	
	update_reticle_options_ui.call()
	
	btn_none.pressed.connect(func():
		if _is_scroll_dragging():
			return
		if not sniper_reticle_enabled:
			return
		sniper_reticle_enabled = false
		sound_mgr.play_click()
		if is_instance_valid(slider) and slider.has_method("set_sniper_reticle_enabled"):
			slider.set_sniper_reticle_enabled(false)
		update_reticle_options_ui.call()
		save_skin_data()
	)
	
	btn_sniper.pressed.connect(func():
		if _is_scroll_dragging():
			return
		if sniper_reticle_enabled:
			return
		sniper_reticle_enabled = true
		sound_mgr.play_click()
		if is_instance_valid(slider) and slider.has_method("set_sniper_reticle_enabled"):
			slider.set_sniper_reticle_enabled(true)
		update_reticle_options_ui.call()
		save_skin_data()
	)
	
	# --- PALETTE SECTION (always created; shown only when Classic is active) ---
	var pal_section = VBoxContainer.new()
	pal_section.add_theme_constant_override("separation", 8)
	pal_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pal_section.visible = true
	_pal_section_root = pal_section
	drawer_content.add_child(pal_section)
	
	var _spacer = Control.new()
	_spacer.custom_minimum_size = Vector2(0, 6)
	pal_section.add_child(_spacer)
	
	var pal_header = Label.new()
	pal_header.text = "COLOR PALETTES"
	pal_header.add_theme_font_size_override("font_size", 12)
	pal_header.add_theme_color_override("font_color", Color(0.55, 0.64, 0.82, 0.80))
	pal_section.add_child(pal_header)
	
	var pal_grid = GridContainer.new()
	pal_grid.columns = 3
	pal_grid.add_theme_constant_override("h_separation", 8)
	pal_grid.add_theme_constant_override("v_separation", 8)
	pal_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pal_section.add_child(pal_grid)
	
	for i in range(PALETTES.size()):
		var pal = PALETTES[i]
		var is_pal_active = (i == palette_index)
		
		var pal_btn = Button.new()
		pal_btn.flat = false
		pal_btn.focus_mode = Control.FOCUS_NONE
		pal_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pal_btn.custom_minimum_size = Vector2(0, 88)
		
		var ps = _make_tile_style(is_pal_active, 4)
		var ps_h = ps.duplicate() as StyleBoxFlat
		ps_h.bg_color = ps.bg_color.lightened(0.06)
		pal_btn.add_theme_stylebox_override("normal", ps)
		pal_btn.add_theme_stylebox_override("hover", ps_h)
		pal_btn.add_theme_stylebox_override("pressed", ps)
		pal_btn.add_theme_stylebox_override("focus", ps)
		
		var p_inner = VBoxContainer.new()
		p_inner.alignment = BoxContainer.ALIGNMENT_CENTER
		p_inner.add_theme_constant_override("separation", 4)
		p_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p_inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pal_btn.add_child(p_inner)
		
		# Color swatch strip
		var swatch_row = HBoxContainer.new()
		swatch_row.add_theme_constant_override("separation", 2)
		swatch_row.alignment = BoxContainer.ALIGNMENT_CENTER
		swatch_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var is_trans = pal.get("is_transparent", false)
		if pal.get("mode", "") == "rainbow":
			var sample_hues = [0.0, 0.16, 0.33, 0.5, 0.66, 0.83]
			var pal_alpha = float(pal.get("alpha", 1.0))
			for h in sample_hues:
				var sw = PanelContainer.new()
				sw.custom_minimum_size = Vector2(14, 14)
				sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var sc = Color.from_hsv(h, float(pal.get("sat", 0.54)), float(pal.get("val", 0.92)))
				sc.a = pal_alpha
				var sb = StyleBoxFlat.new()
				sb.bg_color = sc
				sb.set_corner_radius_all(2)
				if is_trans:
					sb.set_border_width_all(1)
					sb.border_color = Color(1.0, 1.0, 1.0, 0.5)
				sw.add_theme_stylebox_override("panel", sb)
				swatch_row.add_child(sw)
		else:
			var colors = pal.get("colors", []) as Array
			for c in colors:
				var sw = PanelContainer.new()
				sw.custom_minimum_size = Vector2(14, 14)
				sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var sb = StyleBoxFlat.new()
				sb.bg_color = c as Color
				sb.set_corner_radius_all(2)
				if is_trans:
					sb.set_border_width_all(1)
					sb.border_color = Color(1.0, 1.0, 1.0, 0.5)
				sw.add_theme_stylebox_override("panel", sb)
				swatch_row.add_child(sw)
		p_inner.add_child(swatch_row)
		
		var p_name = Label.new()
		p_name.text = pal.get("name", "Palette " + str(i + 1))
		p_name.add_theme_font_size_override("font_size", 9)
		p_name.add_theme_color_override("font_color",
			Color(0.80, 0.86, 1.0, 0.95) if is_pal_active else Color(0.58, 0.65, 0.80, 0.80))
		p_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		p_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p_inner.add_child(p_name)
		
		if is_pal_active:
			var p_check = _create_selection_square()
			p_inner.add_child(p_check)
		
		# Connect palette select — update in-place, no drawer rebuild
		var chosen_idx = i
		pal_btn.pressed.connect(func():
			if _is_scroll_dragging():
				return
			if palette_index == chosen_idx:
				return
			palette_index = chosen_idx
			sound_mgr.play_click()
			var p_data = PALETTES[palette_index]
			var top_c = p_data.get("bg_top", Color(0.08, 0.09, 0.18)) as Color
			var bot_c = p_data.get("bg_bottom", Color(0.20, 0.14, 0.28)) as Color
			_transition_gradient_background(top_c, bot_c)
			_update_pedestal_color(true)
			_update_active_skins_in_scene()
			_refresh_pal_tiles()
			save_skin_data()
		)
		_pal_tile_btns.append(pal_btn)
		pal_grid.add_child(pal_btn)

func _open_challenge_drawer() -> void:
	_open_drawer("CHALLENGE MODES")
	if is_instance_valid(drawer_scroll):
		drawer_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	var container = MarginContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_theme_constant_override("margin_left", 2)
	container.add_theme_constant_override("margin_right", 6)
	container.add_theme_constant_override("margin_top", 2)
	container.add_theme_constant_override("margin_bottom", 2)
	drawer_content.add_child(container)
	
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(grid)
	
	for c in CHALLENGES:
		var is_active = (c["id"] == active_challenge_id)
		
		var tile_btn = Button.new()
		tile_btn.flat = false
		tile_btn.focus_mode = Control.FOCUS_NONE
		tile_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tile_btn.size_flags_stretch_ratio = 1.0
		tile_btn.custom_minimum_size = Vector2(0, 156)
		
		var tile_style = _make_tile_style(is_active, 6)
		var tile_hover = tile_style.duplicate() as StyleBoxFlat
		tile_hover.bg_color = tile_style.bg_color.lightened(0.06)
		tile_btn.add_theme_stylebox_override("normal", tile_style)
		tile_btn.add_theme_stylebox_override("hover", tile_hover)
		tile_btn.add_theme_stylebox_override("pressed", tile_style)
		tile_btn.add_theme_stylebox_override("focus", tile_style)
		
		var margin = MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_top", 12)
		margin.add_theme_constant_override("margin_bottom", 12)
		tile_btn.add_child(margin)
		
		var inner = VBoxContainer.new()
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.add_theme_constant_override("separation", 6)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(inner)
		
		var parts = c["title"].split(" ", false, 1)
		var icon_str = parts[0] if parts.size() > 0 else "⚡"
		var title_str = parts[1] if parts.size() > 1 else c["title"]
		
		var icon_lbl = Label.new()
		icon_lbl.text = icon_str
		icon_lbl.add_theme_font_size_override("font_size", 34)
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(icon_lbl)
		
		var title_lbl = Label.new()
		title_lbl.text = title_str.to_upper()
		title_lbl.add_theme_font_size_override("font_size", 13)
		title_lbl.add_theme_color_override("font_color",
			Color(0.94, 0.96, 1.0, 1.0) if is_active else Color(0.70, 0.76, 0.88, 0.85))
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(title_lbl)
		
		var desc_lbl = Label.new()
		desc_lbl.text = c["desc"]
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.add_theme_color_override("font_color",
			Color(0.75, 0.82, 0.94, 0.90) if is_active else Color(0.52, 0.60, 0.74, 0.80))
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(desc_lbl)
		
		var badge = _create_selection_square()
		badge.modulate.a = 1.0 if is_active else 0.0
		inner.add_child(badge)
		
		var cid = c["id"]
		var c_speed = c["speed"]
		var c_perf = c["perf"]
		tile_btn.pressed.connect(func():
			if _is_scroll_dragging():
				return
			if active_challenge_id == cid:
				return
			active_challenge_id = cid
			challenge_speed_multiplier = c_speed
			challenge_perfect_multiplier = c_perf
			sound_mgr.play_click()
			if state == GameState.MENU:
				slider.speed_multiplier = 0.85 * challenge_speed_multiplier
			_open_challenge_drawer()
		)
		
		grid.add_child(tile_btn)

func _open_campaign_drawer() -> void:
	_open_drawer("CAMPAIGN STAGES", true)
	
	if _campaign_selected_stage_id <= 0 or _campaign_selected_stage_id > CAMPAIGN_STAGES.size():
		_campaign_selected_stage_id = clampi(campaign_unlocked_stage, 1, CAMPAIGN_STAGES.size())
	
	# If currently selected stage is already cleared, auto-select the latest unlocked stage
	if is_stage_cleared(_campaign_selected_stage_id) and _campaign_selected_stage_id < campaign_unlocked_stage:
		_campaign_selected_stage_id = clampi(campaign_unlocked_stage, 1, CAMPAIGN_STAGES.size())
	
	# Chapter Overview & Active Selection Card
	var summary_card = _create_card_container()
	var s_vbox = VBoxContainer.new()
	s_vbox.add_theme_constant_override("separation", 8)
	summary_card.add_child(s_vbox)
	
	var header_row = HBoxContainer.new()
	var chap_lbl = Label.new()
	chap_lbl.text = "👑 CAMPAIGN: %d / %d CLEARED" % [campaign_completed_stages.size(), CAMPAIGN_STAGES.size()]
	chap_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chap_lbl.add_theme_font_size_override("font_size", 14)
	chap_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35, 1.0))
	header_row.add_child(chap_lbl)
	s_vbox.add_child(header_row)
	
	var p_bar = ProgressBar.new()
	p_bar.custom_minimum_size = Vector2(0, 6)
	p_bar.show_percentage = false
	p_bar.max_value = float(CAMPAIGN_STAGES.size())
	p_bar.value = float(campaign_completed_stages.size())
	var bg_st = StyleBoxFlat.new()
	bg_st.bg_color = Color(0.14, 0.17, 0.25, 0.75)
	bg_st.set_corner_radius_all(3)
	var fill_st = StyleBoxFlat.new()
	fill_st.bg_color = Color(0.95, 0.75, 0.25, 0.95)
	fill_st.set_corner_radius_all(3)
	p_bar.add_theme_stylebox_override("background", bg_st)
	p_bar.add_theme_stylebox_override("fill", fill_st)
	s_vbox.add_child(p_bar)
	
	# Selected Stage Row & Action
	var sel_st = CAMPAIGN_STAGES[_campaign_selected_stage_id - 1]
	var sel_is_unlocked = is_stage_unlocked(_campaign_selected_stage_id)
	var sel_is_cleared = is_stage_cleared(_campaign_selected_stage_id)
	
	var mission_row = HBoxContainer.new()
	mission_row.add_theme_constant_override("separation", 8)
	
	var m_info_vbox = VBoxContainer.new()
	m_info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_info_vbox.add_theme_constant_override("separation", 2)
	
	var m_title = Label.new()
	m_title.text = "%s %s" % [sel_st["badge"], sel_st["title"]]
	m_title.add_theme_font_size_override("font_size", 13)
	m_title.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0, 1.0))
	m_info_vbox.add_child(m_title)
	
	var m_desc = Label.new()
	var goal_str = "Target: %d Blocks" % sel_st["target_blocks"]
	if sel_st["target_combo"] > 0:
		goal_str += " • Streak x%d" % sel_st["target_combo"]
	goal_str += " • ⭐ +%d EXP" % sel_st["exp_reward"]
	m_desc.text = goal_str
	m_desc.add_theme_font_size_override("font_size", 10)
	m_desc.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0, 0.85))
	m_info_vbox.add_child(m_desc)
	mission_row.add_child(m_info_vbox)
	
	var play_btn = Button.new()
	play_btn.custom_minimum_size = Vector2(88, 34)
	play_btn.add_theme_font_size_override("font_size", 11)
	var p_btn_st = StyleBoxFlat.new()
	p_btn_st.set_corner_radius_all(4)
	if not sel_is_unlocked:
		play_btn.text = "LOCKED"
		play_btn.disabled = true
		p_btn_st.bg_color = Color(0.12, 0.14, 0.20, 0.60)
		play_btn.add_theme_color_override("font_color", Color(0.48, 0.54, 0.65, 0.6))
	elif sel_is_cleared:
		play_btn.text = "REPLAY"
		p_btn_st.bg_color = Color(0.15, 0.45, 0.32, 0.90)
		play_btn.add_theme_color_override("font_color", Color(0.90, 0.98, 0.92, 1.0))
		var chosen_id = _campaign_selected_stage_id
		play_btn.pressed.connect(func():
			if _is_scroll_dragging():
				return
			start_campaign_stage(chosen_id)
		)
	else:
		play_btn.text = "PLAY"
		p_btn_st.bg_color = Color(0.18, 0.45, 0.85, 0.95)
		play_btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		var chosen_id = _campaign_selected_stage_id
		play_btn.pressed.connect(func():
			if _is_scroll_dragging():
				return
			start_campaign_stage(chosen_id)
		)
	play_btn.add_theme_stylebox_override("normal", p_btn_st)
	play_btn.add_theme_stylebox_override("hover", p_btn_st)
	play_btn.add_theme_stylebox_override("pressed", p_btn_st)
	mission_row.add_child(play_btn)
	s_vbox.add_child(mission_row)
	
	drawer_content.add_child(summary_card)
	
	# 4-Column Stages Grid with square tile buttons
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drawer_content.add_child(grid)
	
	for i in range(CAMPAIGN_STAGES.size()):
		var st = CAMPAIGN_STAGES[i]
		var st_id = st["id"]
		var is_unlocked = is_stage_unlocked(st_id)
		var is_cleared = is_stage_cleared(st_id)
		var is_selected = (st_id == _campaign_selected_stage_id)
		
		var tile_btn = Button.new()
		tile_btn.flat = false
		tile_btn.focus_mode = Control.FOCUS_NONE
		tile_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile_btn.custom_minimum_size = Vector2(0, 76)
		
		var tile_style: StyleBoxFlat
		if is_selected:
			tile_style = _make_tile_style(true, 4)
		elif is_cleared:
			tile_style = _make_tile_style(false, 4)
			tile_style.border_color = Color(0.35, 0.90, 0.55, 0.35)
			tile_style.bg_color = Color(0.08, 0.16, 0.14, 0.90)
		elif is_unlocked:
			tile_style = _make_tile_style(false, 4)
			tile_style.border_color = Color(1.0, 1.0, 1.0, 0.12)
			tile_style.bg_color = Color(0.10, 0.13, 0.20, 0.90)
		else:
			tile_style = _make_tile_style(false, 4)
			tile_style.border_color = Color(1.0, 1.0, 1.0, 0.04)
			tile_style.bg_color = Color(0.07, 0.08, 0.12, 0.60)
		
		var tile_hover = tile_style.duplicate() as StyleBoxFlat
		tile_hover.bg_color = tile_style.bg_color.lightened(0.06)
		tile_btn.add_theme_stylebox_override("normal", tile_style)
		tile_btn.add_theme_stylebox_override("hover", tile_hover)
		tile_btn.add_theme_stylebox_override("pressed", tile_style)
		tile_btn.add_theme_stylebox_override("focus", tile_style)
		
		var inner = VBoxContainer.new()
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.add_theme_constant_override("separation", 2)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tile_btn.add_child(inner)
		
		var icon_lbl = Label.new()
		if not is_unlocked:
			icon_lbl.text = "🔒"
			icon_lbl.add_theme_font_size_override("font_size", 16)
		else:
			icon_lbl.text = st["badge"]
			icon_lbl.add_theme_font_size_override("font_size", 18)
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(icon_lbl)
		
		var num_lbl = Label.new()
		num_lbl.text = str(st_id)
		num_lbl.add_theme_font_size_override("font_size", 11)
		if is_selected:
			num_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		elif is_cleared:
			num_lbl.add_theme_color_override("font_color", Color(0.50, 0.95, 0.65, 0.95))
		elif is_unlocked:
			num_lbl.add_theme_color_override("font_color", Color(0.85, 0.90, 1.0, 0.90))
		else:
			num_lbl.add_theme_color_override("font_color", Color(0.40, 0.45, 0.55, 0.50))
		num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(num_lbl)
		
		if is_selected:
			var badge = _create_selection_square()
			inner.add_child(badge)
		elif is_cleared:
			var clr_lbl = Label.new()
			clr_lbl.text = "✓"
			clr_lbl.add_theme_font_size_override("font_size", 8)
			clr_lbl.add_theme_color_override("font_color", Color(0.35, 0.90, 0.55, 0.9))
			clr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			clr_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner.add_child(clr_lbl)
		
		var target_id = st_id
		tile_btn.pressed.connect(func():
			if _is_scroll_dragging():
				return
			if not is_unlocked:
				sound_mgr.play_click()
				_show_task_toast("🔒 Stage %d is locked! Clear Stage %d first." % [target_id, target_id - 1])
				return
			if _campaign_selected_stage_id == target_id:
				start_campaign_stage(target_id)
			else:
				_campaign_selected_stage_id = target_id
				sound_mgr.play_click()
				_open_campaign_drawer()
		)
		
		grid.add_child(tile_btn)

func start_campaign_stage(stage_id: int) -> void:
	active_campaign_stage_id = stage_id
	start_game_from_menu()

func _check_campaign_stage_progress() -> void:
	if active_campaign_stage_id <= 0:
		return
	for st in CAMPAIGN_STAGES:
		if st["id"] == active_campaign_stage_id:
			var target_blocks: int = st["target_blocks"]
			var target_combo: int = st["target_combo"]
			var height_met = (stack.size() >= target_blocks)
			var combo_met = (target_combo <= 0 or best_combo >= target_combo)
			if height_met and combo_met:
				if not is_stage_cleared(active_campaign_stage_id):
					campaign_completed_stages.append(active_campaign_stage_id)
					campaign_unlocked_stage = maxi(campaign_unlocked_stage, active_campaign_stage_id + 1)
					save_campaign_data()
					var reward = st["exp_reward"]
					total_exp += reward
					save_exp_data()
					_update_exp_badge(true)
					sound_mgr.play_perfect(6)
					var next_id = min(active_campaign_stage_id + 1, CAMPAIGN_STAGES.size())
					_campaign_selected_stage_id = next_id
					_show_task_toast("👑 %s CLEARED! (+%d EXP) • STAGE %d UNLOCKED!" % [st["title"], reward, next_id])
					prompt_label.text = "👑 STAGE CLEARED! STAGE %d UNLOCKED!" % next_id
					prompt_label.visible = true
				else:
					prompt_label.text = "👑 STAGE COMPLETED! KEEP STACKING!"
					prompt_label.visible = true
				break

func _open_levels_drawer() -> void:
	_open_exp_drawer()

func _open_exp_drawer() -> void:
	_open_drawer("EXPERIENCE & MISSIONS")
	
	var rank = get_current_rank_info()
	var current_lvl: int = rank["level"]
	var current_title: String = rank["name"]
	var current_icon: String = rank["icon"]
	var min_exp: int = rank["min_exp"]
	var next_exp: int = rank["next_exp"]
	
	# Current Rank Header Card
	var summary_card = _create_card_container()
	var s_vbox = VBoxContainer.new()
	s_vbox.add_theme_constant_override("separation", 8)
	summary_card.add_child(s_vbox)
	
	var top_row = HBoxContainer.new()
	var rank_lbl = Label.new()
	rank_lbl.text = "%s LEVEL %d: %s" % [current_icon, current_lvl, current_title.to_upper()]
	rank_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rank_lbl.add_theme_font_size_override("font_size", 16)
	rank_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35, 1.0))
	top_row.add_child(rank_lbl)
	
	var exp_badge = Label.new()
	exp_badge.text = "⭐ %d EXP" % total_exp
	exp_badge.add_theme_font_size_override("font_size", 15)
	exp_badge.add_theme_color_override("font_color", Color(0.45, 0.85, 1.0, 1.0))
	top_row.add_child(exp_badge)
	s_vbox.add_child(top_row)
	
	var p_vbox = VBoxContainer.new()
	p_vbox.add_theme_constant_override("separation", 3)
	
	var next_lbl = Label.new()
	if next_exp < 999999:
		var exp_in_lvl = clamp(total_exp - min_exp, 0, next_exp - min_exp)
		var exp_needed = next_exp - min_exp
		next_lbl.text = "Progress to Level %d: %d / %d EXP" % [current_lvl + 1, exp_in_lvl, exp_needed]
	else:
		next_lbl.text = "Max Stacker Rank Achieved 👑"
	next_lbl.add_theme_font_size_override("font_size", 12)
	next_lbl.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95, 0.8))
	p_vbox.add_child(next_lbl)
	
	var p_bar = ProgressBar.new()
	p_bar.custom_minimum_size = Vector2(0, 10)
	p_bar.show_percentage = false
	if next_exp < 999999:
		p_bar.max_value = float(next_exp - min_exp)
		p_bar.value = float(clamp(total_exp - min_exp, 0, next_exp - min_exp))
	else:
		p_bar.max_value = 1.0
		p_bar.value = 1.0
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.14, 0.17, 0.25, 0.75)
	bg_style.set_corner_radius_all(5)
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(1.0, 0.78, 0.28, 0.95)
	fill_style.set_corner_radius_all(5)
	p_bar.add_theme_stylebox_override("background", bg_style)
	p_bar.add_theme_stylebox_override("fill", fill_style)
	p_vbox.add_child(p_bar)
	s_vbox.add_child(p_vbox)
	
	drawer_content.add_child(summary_card)
	
	var today = _get_today_date_str()
	var login_ready = (login_claimed_date != today)
	var perfect_ready = (perfect_3_claimed_date != today and daily_best_combo >= 3)
	var stack_50_ready = (stack_50_claimed_date != today and daily_best_stack >= 50)
	var stack_100_ready = (stack_100_claimed_date != today and daily_best_stack >= 100)
	var ready_count = (1 if login_ready else 0) + (1 if perfect_ready else 0) + (1 if stack_50_ready else 0) + (1 if stack_100_ready else 0)
	
	if ready_count > 1:
		var claim_all_btn = Button.new()
		claim_all_btn.custom_minimum_size = Vector2(0, 42)
		claim_all_btn.text = "★ CLAIM ALL REWARDS (%d TASKS READY) ★" % ready_count
		claim_all_btn.add_theme_font_size_override("font_size", 14)
		var ca_style = StyleBoxFlat.new()
		ca_style.bg_color = Color(0.20, 0.65, 0.38, 1.0)
		ca_style.set_corner_radius_all(6)
		claim_all_btn.add_theme_stylebox_override("normal", ca_style)
		claim_all_btn.add_theme_stylebox_override("hover", ca_style)
		claim_all_btn.add_theme_stylebox_override("pressed", ca_style)
		claim_all_btn.pressed.connect(func():
			if _is_scroll_dragging():
				return
			claim_all_available_exp()
		)
		drawer_content.add_child(claim_all_btn)
	
	var section_lbl = Label.new()
	section_lbl.text = "DAILY MISSIONS (RESETS DAILY)"
	section_lbl.add_theme_font_size_override("font_size", 13)
	section_lbl.add_theme_color_override("font_color", Color(0.55, 0.72, 0.95, 0.85))
	drawer_content.add_child(section_lbl)
	
	var missions = [
		{
			"id": "login",
			"icon": "📅",
			"name": "Daily Check-in",
			"exp": 1,
			"desc": "Check into Stack Adventure each day to earn bonus EXP.",
			"ready": login_ready,
			"claimed": login_claimed_date == today,
			"cur": 1 if (login_claimed_date == today or login_ready) else 0,
			"target": 1,
			"unit": "Day"
		},
		{
			"id": "perfect_3",
			"icon": "🎯",
			"name": "Triple Precision (Perfect x3)",
			"exp": 2,
			"desc": "Land 3 consecutive perfect drops in a single run today.",
			"ready": perfect_ready,
			"claimed": perfect_3_claimed_date == today,
			"cur": min(daily_best_combo, 3),
			"target": 3,
			"unit": "Combo"
		},
		{
			"id": "stack_50",
			"icon": "🏗️",
			"name": "Tower of Fifty",
			"exp": 1,
			"desc": "Build a tower reaching at least 50 blocks high today.",
			"ready": stack_50_ready,
			"claimed": stack_50_claimed_date == today,
			"cur": min(daily_best_stack, 50),
			"target": 50,
			"unit": "Blocks"
		},
		{
			"id": "stack_100",
			"icon": "🚀",
			"name": "Sky Century",
			"exp": 2,
			"desc": "Ascend past the clouds to reach a 100-block tower today.",
			"ready": stack_100_ready,
			"claimed": stack_100_claimed_date == today,
			"cur": min(daily_best_stack, 100),
			"target": 100,
			"unit": "Blocks"
		}
	]
	
	for m in missions:
		var card = _create_card_container()
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)
		card.add_child(vbox)
		
		var header_row = HBoxContainer.new()
		var title_lbl = Label.new()
		title_lbl.text = m["icon"] + " " + m["name"]
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_lbl.add_theme_font_size_override("font_size", 15)
		title_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		header_row.add_child(title_lbl)
		
		var exp_reward_lbl = Label.new()
		exp_reward_lbl.text = "+%d EXP" % m["exp"]
		exp_reward_lbl.add_theme_font_size_override("font_size", 14)
		exp_reward_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35, 1.0))
		header_row.add_child(exp_reward_lbl)
		vbox.add_child(header_row)
		
		var desc_lbl = Label.new()
		desc_lbl.text = m["desc"]
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", Color(0.68, 0.73, 0.85, 0.75))
		vbox.add_child(desc_lbl)
		
		if m["claimed"]:
			var claimed_lbl = Label.new()
			claimed_lbl.text = "✓ CLAIMED TODAY"
			claimed_lbl.add_theme_font_size_override("font_size", 13)
			claimed_lbl.add_theme_color_override("font_color", Color(0.35, 0.90, 0.55, 1.0))
			vbox.add_child(claimed_lbl)
		elif m["ready"]:
			var claim_btn = Button.new()
			claim_btn.custom_minimum_size = Vector2(0, 36)
			claim_btn.text = "★ CLAIM +%d EXP ★" % m["exp"]
			claim_btn.add_theme_font_size_override("font_size", 13)
			var c_style = StyleBoxFlat.new()
			c_style.bg_color = Color(0.85, 0.65, 0.15, 1.0)
			c_style.set_corner_radius_all(5)
			claim_btn.add_theme_stylebox_override("normal", c_style)
			claim_btn.add_theme_stylebox_override("hover", c_style)
			claim_btn.add_theme_stylebox_override("pressed", c_style)
			var mid = m["id"]
			claim_btn.pressed.connect(func():
				if _is_scroll_dragging():
					return
				claim_task_exp(mid)
			)
			vbox.add_child(claim_btn)
		else:
			var prog_row = HBoxContainer.new()
			var prog_lbl = Label.new()
			prog_lbl.text = "In Progress: %d / %d %s" % [m["cur"], m["target"], m["unit"]]
			prog_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			prog_lbl.add_theme_font_size_override("font_size", 12)
			prog_lbl.add_theme_color_override("font_color", Color(0.65, 0.70, 0.82, 0.75))
			prog_row.add_child(prog_lbl)
			vbox.add_child(prog_row)
			
			var m_bar = ProgressBar.new()
			m_bar.custom_minimum_size = Vector2(0, 8)
			m_bar.show_percentage = false
			m_bar.max_value = float(m["target"])
			m_bar.value = float(clamp(m["cur"], 0, m["target"]))
			var m_bg = StyleBoxFlat.new()
			m_bg.bg_color = Color(0.18, 0.22, 0.32, 0.6)
			m_bg.set_corner_radius_all(4)
			var m_fill = StyleBoxFlat.new()
			m_fill.bg_color = Color(0.28, 0.60, 0.90, 0.85)
			m_fill.set_corner_radius_all(4)
			m_bar.add_theme_stylebox_override("background", m_bg)
			m_bar.add_theme_stylebox_override("fill", m_fill)
			vbox.add_child(m_bar)
		
		drawer_content.add_child(card)
	
	# Rank Tiers Section
	var rank_sec_lbl = Label.new()
	rank_sec_lbl.text = "STACKER RANK TIERS"
	rank_sec_lbl.add_theme_font_size_override("font_size", 13)
	rank_sec_lbl.add_theme_color_override("font_color", Color(0.55, 0.72, 0.95, 0.85))
	drawer_content.add_child(rank_sec_lbl)
	
	var tiers_card = _create_card_container()
	var t_vbox = VBoxContainer.new()
	t_vbox.add_theme_constant_override("separation", 6)
	tiers_card.add_child(t_vbox)
	
	for r in EXP_RANKS:
		var r_row = HBoxContainer.new()
		var r_name = Label.new()
		r_name.text = "%s Lvl %d: %s" % [r["icon"], r["level"], r["name"]]
		r_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r_name.add_theme_font_size_override("font_size", 13)
		
		var r_req = Label.new()
		r_req.add_theme_font_size_override("font_size", 12)
		
		if r["level"] == current_lvl:
			r_name.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35, 1.0))
			r_req.text = "▶ CURRENT (%d+ EXP)" % r["min_exp"]
			r_req.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35, 1.0))
		elif total_exp >= r["min_exp"]:
			r_name.add_theme_color_override("font_color", Color(0.85, 0.90, 0.95, 0.9))
			r_req.text = "✓ UNLOCKED"
			r_req.add_theme_color_override("font_color", Color(0.35, 0.90, 0.55, 0.9))
		else:
			r_name.add_theme_color_override("font_color", Color(0.50, 0.55, 0.65, 0.7))
			r_req.text = "🔒 %d EXP" % r["min_exp"]
			r_req.add_theme_color_override("font_color", Color(0.50, 0.55, 0.65, 0.7))
		
		r_row.add_child(r_name)
		r_row.add_child(r_req)
		t_vbox.add_child(r_row)
	
	drawer_content.add_child(tiers_card)

func reset_game() -> void:
	if _is_restarting:
		return
	restart_game()

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
	if _is_restarting:
		return
	
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
		GameState.READY, GameState.PLAYING:
			if is_instance_valid(play_close_btn) and play_close_btn.visible:
				if event is InputEventScreenTouch or event is InputEventMouseButton:
					if play_close_btn.get_global_rect().has_point(event.position):
						return
			if is_instance_valid(sound_btn) and sound_btn.visible:
				if event is InputEventScreenTouch or event is InputEventMouseButton:
					if sound_btn.get_global_rect().has_point(event.position):
						return
			if state == GameState.READY:
				prompt_label.visible = false
			state = GameState.DROPPING
			_drop_current_box()
		GameState.GAME_OVER:
			if Time.get_ticks_msec() - _game_over_time < 350:
				return
			if is_instance_valid(game_over_close_btn) and game_over_close_btn.visible:
				if event is InputEventScreenTouch or event is InputEventMouseButton:
					if game_over_close_btn.get_global_rect().has_point(event.position):
						return
			if is_instance_valid(play_close_btn) and play_close_btn.visible:
				if event is InputEventScreenTouch or event is InputEventMouseButton:
					if play_close_btn.get_global_rect().has_point(event.position):
						return
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
		
		# EXP Tracking: Perfect stack of 3 (daily task)
		if combo >= 3:
			var prev_combo = daily_best_combo
			daily_best_combo = max(daily_best_combo, combo)
			var today = _get_today_date_str()
			if perfect_3_claimed_date != today and prev_combo < 3:
				_show_task_toast("⭐ Task Ready: Perfect Stack of 3 (+2 EXP)!")
				save_exp_data()
		
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
	
	# EXP Tracking: Stack height tasks (50 and 100)
	var prev_stack = daily_best_stack
	daily_best_stack = max(daily_best_stack, stack.size())
	var today = _get_today_date_str()
	if stack.size() == 50 and stack_50_claimed_date != today and prev_stack < 50:
		_show_task_toast("⭐ Task Ready: Stack of 50 (+1 EXP)!")
		save_exp_data()
	elif stack.size() == 100 and stack_100_claimed_date != today and prev_stack < 100:
		_show_task_toast("⭐ Task Ready: Stack of 100 (+2 EXP)!")
		save_exp_data()
	
	# Campaign Stage Progression
	if active_campaign_stage_id > 0:
		_check_campaign_stage_progress()
	
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
	# Smooth kinetic inertia for drawer touch scrolling
	if is_instance_valid(drawer_modal) and drawer_modal.visible and is_instance_valid(drawer_scroll) and not _scroll_touch_active:
		if abs(_scroll_velocity_y) > 15.0:
			var max_scroll = _get_max_drawer_scroll()
			var next_val = clampi(int(round(drawer_scroll.scroll_vertical - _scroll_velocity_y * delta)), 0, max_scroll)
			if next_val == drawer_scroll.scroll_vertical and (next_val == 0 or next_val == max_scroll):
				_scroll_velocity_y = 0.0
			else:
				drawer_scroll.scroll_vertical = next_val
				_scroll_velocity_y = lerp(_scroll_velocity_y, 0.0, clamp(delta * 7.0, 0.0, 1.0))
		else:
			_scroll_velocity_y = 0.0

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
	
	save_exp_data()
	
	if active_campaign_stage_id > 0 and is_stage_cleared(active_campaign_stage_id):
		var next_stage = min(active_campaign_stage_id + 1, CAMPAIGN_STAGES.size())
		active_campaign_stage_id = next_stage
		_campaign_selected_stage_id = next_stage
	
	final_score_label.text = "SCORE: " + str(score)
	best_score_label.text = "BEST: " + str(high_score)
	new_best_badge.visible = is_new_record
	
	# Do not show game over panel — simply show message
	game_over_panel.visible = false
	
	# Cinematic camera zoom-out to reveal the full tower
	_animate_game_over_tower_reveal()
	
	# Simply show the message 'Tap To Play Again' and big close button above it at left
	_stop_play_again_pulse()
	prompt_label.text = "Tap To Play Again"
	prompt_label.visible = true
	prompt_label.modulate.a = 0.0
	
	if is_instance_valid(play_close_btn):
		play_close_btn.visible = true
	if is_instance_valid(game_over_close_btn):
		game_over_close_btn.visible = true
		game_over_close_btn.modulate.a = 0.0
	
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.30)
	tween.tween_property(prompt_label, "modulate:a", 1.0, 0.25)
	if is_instance_valid(game_over_close_btn):
		tween.parallel().tween_property(game_over_close_btn, "modulate:a", 1.0, 0.25)
	tween.tween_callback(func():
		if state == GameState.GAME_OVER:
			_start_play_again_pulse()
	)

func _start_play_again_pulse() -> void:
	if play_again_pulse_tween:
		play_again_pulse_tween.kill()
	play_again_pulse_tween = create_tween().set_loops()
	play_again_pulse_tween.tween_property(prompt_label, "modulate:a", 0.40, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	play_again_pulse_tween.tween_property(prompt_label, "modulate:a", 1.0, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_play_again_pulse() -> void:
	if play_again_pulse_tween:
		play_again_pulse_tween.kill()
		play_again_pulse_tween = null
	if is_instance_valid(prompt_label):
		prompt_label.modulate.a = 1.0

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
	if _is_restarting:
		return
	_is_restarting = true
	
	sound_mgr.play_click()
	_stop_play_again_pulse()
	prompt_label.visible = false
	if is_instance_valid(game_over_close_btn):
		game_over_close_btn.visible = false
	
	if game_over_zoom_tween:
		game_over_zoom_tween.kill()
		game_over_zoom_tween = null
	if _restart_tween:
		_restart_tween.kill()
		_restart_tween = null
	
	# 1. Destroy the stack with blocks blasting outward in various directions
	var boxes_to_destroy = stack.duplicate()
	stack.clear()
	
	if is_instance_valid(active_box):
		boxes_to_destroy.append(active_box)
		active_box = null
	
	var count = boxes_to_destroy.size()
	
	trigger_screen_shake(0.35)
	sound_mgr.play_land()
	_spawn_impact_dust(Vector3(0, 0.2, 0))
	if count > 4:
		_spawn_impact_dust(Vector3(0, current_top_y * 0.5, 0))
	
	# Pick a random fall direction for the entire stack (360 degrees)
	var fall_angle = randf_range(0.0, TAU)
	var fall_dir = Vector2(cos(fall_angle), sin(fall_angle))
	# Perpendicular axis for forward toppling tilt
	var tilt_axis = Vector3(-fall_dir.y, 0.0, fall_dir.x)
	
	for i in range(count):
		var b = boxes_to_destroy[i]
		if not is_instance_valid(b):
			continue
		
		# Height fraction from bottom (0.0) to top (1.0)
		var h_frac = float(i + 1) / float(max(1, count))
		
		# In a toppling tower, higher blocks swing much farther in the fall direction
		var horiz_dist = lerp(4.0, 18.0, h_frac) * randf_range(0.9, 1.15)
		# Slight natural spread around the main fall direction
		var block_angle = fall_angle + randf_range(-0.16, 0.16)
		var target_x = b.position.x + cos(block_angle) * horiz_dist
		var target_z = b.position.z + sin(block_angle) * horiz_dist
		
		# Vertical motion: top blocks drop farther as the tower topples over
		var lift = lerp(0.3, 1.8, h_frac)
		var fall = lerp(8.0, 22.0, h_frac)
		
		# Forward tilt in the fall direction + gentle 3D tumbling
		var tilt_amount = lerp(1.2, 2.6, h_frac)
		var spin_rot = b.rotation + (tilt_axis * tilt_amount) + Vector3(
			randf_range(-0.6, 0.6),
			randf_range(-0.6, 0.6),
			randf_range(-0.6, 0.6)
		)
		
		# Progressive top-to-bottom collapse wave
		var delay = clamp(float(count - 1 - i) * 0.018, 0.0, 0.22)
		var duration = randf_range(0.90, 1.10)
		
		var bt = create_tween().set_parallel(true)
		# Horizontal displacement accelerating naturally under gravity
		bt.tween_property(b, "position:x", target_x, duration).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		bt.tween_property(b, "position:z", target_z, duration).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		bt.tween_property(b, "rotation", spin_rot, duration).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
		# Maintain size while toppling, then smoothly shrink down as it drops
		var shrink_delay = delay + duration * 0.45
		var shrink_dur = duration * 0.55
		bt.tween_property(b, "scale", Vector3(0.01, 0.01, 0.01), shrink_dur).set_delay(shrink_delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		
		# Vertical arc: initial lean lift then downward gravity plunge
		var duration_up = duration * 0.26
		var duration_down = duration * 0.74
		var yt = create_tween()
		if delay > 0.0:
			yt.tween_interval(delay)
		yt.tween_property(b, "position:y", b.position.y + lift, duration_up).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		yt.tween_property(b, "position:y", b.position.y - fall, duration_down).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
		# Free block once animation completes
		bt.chain().tween_callback(func():
			if is_instance_valid(b):
				b.queue_free()
		)
	
	# 2. Main base appears from the bottom
	const BASE_DROP_OFFSET: float = 6.0
	if is_instance_valid(base_pedestal):
		base_pedestal.position.y = -12.0 - BASE_DROP_OFFSET
	if is_instance_valid(pedestal_rim):
		pedestal_rim.position.y = 0.0 - BASE_DROP_OFFSET
	if is_instance_valid(pedestal_mist_particles):
		pedestal_mist_particles.position.y = -6.0 - BASE_DROP_OFFSET
	
	# Calculate target camera size for normal view
	var aspect_mult = 1.0
	var win_size = get_viewport().get_visible_rect().size
	if win_size.y > 0.0:
		var aspect = win_size.x / win_size.y
		if aspect < 0.5625:
			aspect_mult = 0.5625 / aspect
	var normal_camera_size = BASE_CAMERA_SIZE * aspect_mult
	
	# Animate camera returning to ground and main base rising smoothly from the bottom
	_restart_tween = create_tween().set_parallel(true)
	
	# Camera returns smoothly to base with matching cinematic timing
	_restart_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_restart_tween.tween_property(camera, "size", normal_camera_size, 0.78).set_delay(0.32)
	_restart_tween.tween_property(self, "target_camera_y", base_camera_pivot_y, 0.78).set_delay(0.32)
	_restart_tween.tween_property(self, "target_camera_x", 0.0, 0.78).set_delay(0.32)
	_restart_tween.tween_property(self, "target_camera_z", 0.0, 0.78).set_delay(0.32)
	
	# Main base rises up smoothly from bottom
	if is_instance_valid(base_pedestal):
		_restart_tween.tween_property(base_pedestal, "position:y", -12.0, 0.68).set_delay(0.40).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_instance_valid(pedestal_rim):
		_restart_tween.tween_property(pedestal_rim, "position:y", 0.0, 0.68).set_delay(0.40).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_instance_valid(pedestal_mist_particles):
		_restart_tween.tween_property(pedestal_mist_particles, "position:y", -6.0, 0.68).set_delay(0.40).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# When the main base has risen into place, start game
	_restart_tween.chain().tween_callback(func():
		_is_restarting = false
		_spawn_impact_dust(Vector3(0, 0.05, 0))
		_finish_restart_game()
	)

func _finish_restart_game() -> void:
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
	if is_instance_valid(play_close_btn):
		play_close_btn.visible = true
	if active_campaign_stage_id > 0:
		for st in CAMPAIGN_STAGES:
			if st["id"] == active_campaign_stage_id:
				prompt_label.text = "%s: TARGET %d BLOCKS" % [st["title"].to_upper(), st["target_blocks"]]
				break
	elif not OS.has_feature("android") and not OS.has_feature("mobile"):
		prompt_label.text = "CLICK OR PRESS SPACE TO DROP"
	else:
		prompt_label.text = "TAP SCREEN TO DROP"
	prompt_label.modulate.a = 1.0
	game_over_panel.visible = false
	if is_instance_valid(game_over_close_btn):
		game_over_close_btn.visible = false
	new_best_badge.visible = false
	
	# Initial slider level
	slider.set_target_level(current_top_y, current_target_pos, 0)
	slider.speed_multiplier = 1.0 * challenge_speed_multiplier
	_update_pedestal_color(false)
	
	_spawn_next_box()


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
		var c = Color.from_hsv(h, float(pal["sat"]), float(pal["val"]))
		if pal.has("alpha"):
			c.a = float(pal["alpha"])
		return c
	else:
		var colors = pal["colors"] as Array
		var count = colors.size()
		var step = index * 0.22 # Smooth transition every ~4-5 blocks
		var idx = int(step) % count
		var next_idx = (idx + 1) % count
		var t = fmod(step, 1.0)
		var smooth_t = (1.0 - cos(t * PI)) * 0.5
		return (colors[idx] as Color).lerp(colors[next_idx] as Color, smooth_t)
