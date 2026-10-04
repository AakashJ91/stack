extends Node3D
class_name CubeSlider

signal box_released(box: Node3D, release_pos: Vector3, release_velocity: Vector3)

# Sliding parameters
@export var slide_amplitude: float = 4.2
@export var base_speed: float = 2.8
@export var speed_multiplier: float = 1.0
@export var hover_height: float = 1.8

var current_time: float = 0.0
var current_target_center: Vector3 = Vector3.ZERO
var current_top_y: float = 0.0
var current_box: Node3D = null
var is_active: bool = true

# 0 = X-axis (left-right in 3D), 1 = Z-axis (front-back in 3D)
var current_axis: int = 0
var current_slide_dir: Vector3 = Vector3.RIGHT

# Alignment guide / shadow projection
var guide_mesh_instance: MeshInstance3D
var guide_material: StandardMaterial3D

func _ready() -> void:
	_setup_guide_projection()

func _setup_guide_projection() -> void:
	guide_mesh_instance = MeshInstance3D.new()
	var plane_mesh = BoxMesh.new()
	plane_mesh.size = Vector3(2.4, 0.02, 2.4)
	guide_mesh_instance.mesh = plane_mesh
	
	guide_material = StandardMaterial3D.new()
	guide_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	guide_material.albedo_color = Color(1.0, 1.0, 1.0, 0.18)
	guide_material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	guide_mesh_instance.material_override = guide_material
	guide_mesh_instance.visible = false
	add_child(guide_mesh_instance)

func set_target_level(top_y: float, target_center: Vector3, axis_index: int) -> void:
	current_top_y = top_y
	current_target_center = target_center
	current_axis = axis_index % 2
	
	if current_axis == 0:
		current_slide_dir = Vector3(1, 0, 0)
	else:
		current_slide_dir = Vector3(0, 0, 1)
	
	# Start from outside the stack
	current_time = -PI * 0.5
	guide_mesh_instance.visible = true

func attach_box(box: Node3D) -> void:
	current_box = box
	box.state = box.BoxState.ATTACHED
	guide_mesh_instance.visible = true

func _process(delta: float) -> void:
	if not is_active:
		return
	
	current_time += delta * (base_speed * speed_multiplier)
	
	# Smooth oscillating slide: offset = amplitude * sin(time)
	var offset = slide_amplitude * sin(current_time)
	
	var box_y = current_top_y + hover_height + (current_box.box_size.y * 0.5 if is_instance_valid(current_box) else 0.4)
	var slide_pos = current_target_center + (current_slide_dir * offset)
	slide_pos.y = box_y
	
	if is_instance_valid(current_box) and current_box.state == current_box.BoxState.ATTACHED:
		current_box.global_position = slide_pos
		
		# Update guide projection shadow on top of tower
		if guide_mesh_instance:
			var guide_pos = slide_pos
			guide_pos.y = current_top_y + 0.02
			guide_mesh_instance.global_position = guide_pos
			
			# Pulse guide alpha subtly with matching cube color
			var dist_to_target = Vector2(slide_pos.x - current_target_center.x, slide_pos.z - current_target_center.z).length()
			var proximity = clamp(1.0 - (dist_to_target / 1.5), 0.0, 1.0)
			if "box_color" in current_box:
				var c = current_box.box_color
				guide_material.albedo_color = Color(c.r, c.g, c.b, 0.18 + (proximity * 0.22))
			else:
				guide_material.albedo_color = Color(1.0, 1.0, 0.4, 0.15 + (proximity * 0.25))

func release_box() -> Node3D:
	if not is_instance_valid(current_box) or current_box.state != current_box.BoxState.ATTACHED:
		return null
	
	var box = current_box
	current_box = null
	
	if guide_mesh_instance:
		guide_mesh_instance.visible = false
	
	# Instantaneous velocity: derivative of sin(current_time)
	var d_offset = slide_amplitude * (base_speed * speed_multiplier) * cos(current_time)
	var release_vel = (current_slide_dir * (d_offset * 0.12)) + Vector3(0, -2.0, 0)
	
	box_released.emit(box, box.global_position, release_vel)
	return box
