extends Node3D

const StackBox = preload("res://scripts/box.gd")

signal box_released(box: Node3D, release_pos: Vector3, release_velocity: Vector3)

# Swing parameters
@export var rope_length: float = 6.0
@export var max_angle: float = 0.52 # ~30 degrees in radians
@export var base_speed: float = 2.4 # Angular frequency omega
@export var speed_multiplier: float = 1.0

var current_time: float = 0.0
var anchor_position: Vector3 = Vector3(0, 12, 0)
var current_hook_pos: Vector3 = Vector3.ZERO
var current_velocity: Vector3 = Vector3.ZERO
var swing_axis_dir: Vector3 = Vector3(1, 0, -1).normalized() # Screen-horizontal in isometric

var current_box: StackBox = null
var is_active: bool = true

# Visual nodes
var rope_mesh: ImmediateMesh
var rope_instance: MeshInstance3D
var hook_marker: MeshInstance3D

func _ready() -> void:
	_setup_visuals()

func _setup_visuals() -> void:
	# Rope ImmediateMesh
	rope_mesh = ImmediateMesh.new()
	rope_instance = MeshInstance3D.new()
	rope_instance.mesh = rope_mesh
	
	var rope_mat = StandardMaterial3D.new()
	rope_mat.shading_mode = StandardMaterial3D.SHADING_MODE_PER_PIXEL
	rope_mat.albedo_color = Color(0.95, 0.75, 0.25) # Golden cable
	rope_mat.metallic = 0.6
	rope_mat.roughness = 0.3
	rope_instance.material_override = rope_mat
	add_child(rope_instance)

	# Hook mesh (small metallic sphere/cylinder)
	hook_marker = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	hook_marker.mesh = sphere
	
	var hook_mat = StandardMaterial3D.new()
	hook_mat.albedo_color = Color(0.3, 0.35, 0.45)
	hook_mat.metallic = 0.9
	hook_mat.roughness = 0.2
	hook_marker.material_override = hook_mat
	add_child(hook_marker)

func set_anchor_y(new_y: float) -> void:
	anchor_position.y = new_y

func attach_box(box: StackBox) -> void:
	current_box = box
	box.state = StackBox.BoxState.ATTACHED
	# Reset or slightly perturb time for variety
	current_time = 0.0

func set_swing_direction(axis_type: int) -> void:
	# 0: Screen-horizontal (1, 0, -1)
	# 1: Screen-depth (1, 0, 1)
	# 2: X-axis (1, 0, 0)
	# 3: Z-axis (0, 0, 1)
	match axis_type % 4:
		0:
			swing_axis_dir = Vector3(1, 0, -1).normalized()
		1:
			swing_axis_dir = Vector3(1, 0, 1).normalized()
		2:
			swing_axis_dir = Vector3(1, 0, 0)
		3:
			swing_axis_dir = Vector3(0, 0, 1)

func _process(delta: float) -> void:
	if !is_active:
		return
	
	current_time += delta * (base_speed * speed_multiplier)
	
	# Pendulum physics: theta = max_angle * sin(current_time)
	var theta = max_angle * sin(current_time)
	var d_theta = max_angle * (base_speed * speed_multiplier) * cos(current_time)
	
	# Hook position relative to anchor
	var horizontal_offset = swing_axis_dir * (rope_length * sin(theta))
	var vertical_offset = -Vector3.UP * (rope_length * cos(theta))
	
	current_hook_pos = anchor_position + horizontal_offset + vertical_offset
	hook_marker.global_position = current_hook_pos
	
	# Tangential velocity: v = L * omega * cos(theta) * direction
	current_velocity = (swing_axis_dir * (rope_length * cos(theta)) + Vector3.UP * (rope_length * sin(theta))) * d_theta
	
	# Update rope visual
	_draw_rope(anchor_position, current_hook_pos)
	
	# Update attached box position
	if is_instance_valid(current_box) and current_box.state == StackBox.BoxState.ATTACHED:
		var box_top_offset = Vector3(0, current_box.box_size.y * 0.5, 0)
		current_box.global_position = current_hook_pos - box_top_offset
		# Slight sway tilt for realistic physical feel
		var sway_axis = swing_axis_dir.cross(Vector3.UP).normalized()
		current_box.transform.basis = Basis(sway_axis, theta * 0.3)

func _draw_rope(from: Vector3, to: Vector3) -> void:
	rope_mesh.clear_surfaces()
	rope_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	rope_mesh.surface_add_vertex(from)
	rope_mesh.surface_add_vertex(to)
	rope_mesh.surface_end()

func release_box() -> StackBox:
	if not is_instance_valid(current_box) or current_box.state != StackBox.BoxState.ATTACHED:
		return null
	
	var box = current_box
	current_box = null
	
	# Reset rotation when released so it drops upright
	box.transform.basis = Basis.IDENTITY
	
	# Release with scaled momentum for satisfying arc/fall
	var release_vel = Vector3(current_velocity.x * 0.25, -1.0, current_velocity.z * 0.25)
	box_released.emit(box, box.global_position, release_vel)
	return box
