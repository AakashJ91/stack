extends Node3D
class_name CubeSlider

signal box_released(box: Node3D, release_pos: Vector3, release_velocity: Vector3)

# Sliding parameters
@export var slide_amplitude: float = 3.3
@export var base_speed: float = 2.8
@export var speed_multiplier: float = 1.0
@export var hover_height: float = 1.8

var current_time: float = 0.0
var current_target_center: Vector3 = Vector3.ZERO
var current_top_y: float = 0.0
var current_box: Node3D = null
var is_active: bool = true

var was_aligned: bool = false

# 0 = X-axis (left-right in 3D), 1 = Z-axis (front-back in 3D)
var current_axis: int = 0
var current_slide_dir: Vector3 = Vector3.RIGHT

# Alignment guide / shadow projection
var guide_mesh_instance: MeshInstance3D
var guide_material: StandardMaterial3D
var _guide_smooth_pos: Vector3 = Vector3.ZERO
const GUIDE_LERP_SPEED: float = 14.0

func _ready() -> void:
	_setup_guide_projection()

func _setup_guide_projection() -> void:
	guide_mesh_instance = MeshInstance3D.new()
	var plane_mesh = BoxMesh.new()
	plane_mesh.size = Vector3(2.4, 0.02, 2.4)
	guide_mesh_instance.mesh = plane_mesh
	
	guide_material = StandardMaterial3D.new()
	guide_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	guide_material.albedo_color = Color(0.2, 0.6, 0.95, 0.0)
	guide_material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	guide_material.render_priority = 2
	guide_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	guide_mesh_instance.material_override = guide_material
	guide_mesh_instance.visible = false
	add_child(guide_mesh_instance)

func set_target_level(top_y: float, target_center: Vector3, axis_index: int) -> void:
	current_top_y = top_y
	current_target_center = target_center
	current_axis = axis_index % 2
	was_aligned = false
	
	if current_axis == 0:
		current_slide_dir = Vector3(1, 0, 0)
	else:
		current_slide_dir = Vector3(0, 0, 1)
	
	# Start from outside the stack directly under the cube
	current_time = -PI * 0.5
	var start_offset = slide_amplitude * sin(current_time)
	var start_pos = current_target_center + (current_slide_dir * start_offset)
	var guide_y = current_top_y + (0.042 if current_top_y == 0.0 else 0.025)
	_guide_smooth_pos = Vector3(start_pos.x, guide_y, start_pos.z)
	guide_mesh_instance.global_position = _guide_smooth_pos
	guide_mesh_instance.visible = true

func attach_box(box: Node3D) -> void:
	current_box = box
	box.state = box.BoxState.ATTACHED
	was_aligned = false
	guide_mesh_instance.visible = true

func _process(delta: float) -> void:
	if not is_active:
		return
	
	current_time += delta * (base_speed * speed_multiplier)
	
	# Smooth oscillating slide: offset = amplitude * sin(time)
	var offset = slide_amplitude * sin(current_time)
	var velocity_factor = cos(current_time) # +1 to -1 indicating instantaneous velocity
	
	# Floating anti-gravity hover bobbing
	var hover_bob = sin(current_time * 3.4) * 0.08
	
	var box_y = current_top_y + hover_height + (current_box.box_size.y * 0.5 if is_instance_valid(current_box) else 0.4) + hover_bob
	var slide_pos = current_target_center + (current_slide_dir * offset)
	slide_pos.y = box_y
	
	var dist_to_target = Vector2(slide_pos.x - current_target_center.x, slide_pos.z - current_target_center.z).length()
	var is_aligned = dist_to_target <= 0.22
	
	was_aligned = is_aligned
	
	if is_instance_valid(current_box) and current_box.state == current_box.BoxState.ATTACHED:
		current_box.global_position = slide_pos
		
		# Drive banking, squash/stretch, and core glow on the cube
		if current_box.has_method("update_slider_motion"):
			current_box.update_slider_motion(delta, velocity_factor, current_axis, is_aligned, current_time)
		
		# Update guide projection — smoothly lerp position so it glides, not snaps
		if guide_mesh_instance:
			var guide_y = current_top_y + (0.042 if current_top_y == 0.0 else 0.025)
			var target_guide = Vector3(slide_pos.x, guide_y, slide_pos.z)
			_guide_smooth_pos = _guide_smooth_pos.lerp(target_guide, clamp(GUIDE_LERP_SPEED * delta, 0.0, 1.0))
			guide_mesh_instance.global_position = _guide_smooth_pos
			
			var smooth_dist = Vector2(_guide_smooth_pos.x - current_target_center.x, _guide_smooth_pos.z - current_target_center.z).length()
			var proximity = clamp(1.0 - (smooth_dist / 1.6), 0.0, 1.0)
			var base_c = current_box.box_color if "box_color" in current_box else Color(1.0, 0.9, 0.4)
			
			if is_aligned:
				# Sweet-spot lock-on: gentle luminous pulse in matching cube color (no white flash)
				var pulse = 0.22 + (sin(current_time * 3.0) * 0.03)
				var aligned_c = Color(base_c.r, base_c.g, base_c.b, pulse)
				guide_material.albedo_color = guide_material.albedo_color.lerp(aligned_c, 0.18)
			else:
				var alpha = 0.07 + (proximity * 0.14)
				guide_material.albedo_color = guide_material.albedo_color.lerp(Color(base_c.r, base_c.g, base_c.b, alpha), 0.12)

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
