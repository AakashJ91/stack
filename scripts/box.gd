extends Node3D
class_name StackBox

enum BoxState { ATTACHED, FALLING, LANDED, TOPPLING }

var state: BoxState = BoxState.ATTACHED
var box_size: Vector3 = Vector3(2.4, 0.8, 2.4)
var velocity: Vector3 = Vector3.ZERO
var gravity: float = 38.0

# Target landing height (y coordinate of top face of the box below)
var target_landing_y: float = 0.0

# Reference to mesh and materials
var mesh_instance: MeshInstance3D
var top_trim_instance: MeshInstance3D
var material: StandardMaterial3D
var topple_axis: Vector3 = Vector3.RIGHT
var topple_speed: float = 8.0

var box_color: Color = Color(0.2, 0.6, 0.95)

signal landed(box: Node3D, hit_target: bool)

func _init() -> void:
	_build_mesh()

func _ready() -> void:
	if not mesh_instance:
		_build_mesh()
	_apply_color()

func _build_mesh() -> void:
	if mesh_instance:
		return
	mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = box_size
	mesh_instance.mesh = box_mesh
	
	material = StandardMaterial3D.new()
	material.shading_mode = StandardMaterial3D.SHADING_MODE_PER_PIXEL
	material.roughness = 0.3
	material.metallic = 0.1
	material.albedo_color = box_color
	mesh_instance.material_override = material
	add_child(mesh_instance)
	
	# Elegant top surface trim / border for enhanced isometric readability
	top_trim_instance = MeshInstance3D.new()
	var trim_mesh = BoxMesh.new()
	trim_mesh.size = Vector3(box_size.x * 0.94, 0.04, box_size.z * 0.94)
	top_trim_instance.mesh = trim_mesh
	top_trim_instance.position = Vector3(0, box_size.y * 0.5 + 0.02, 0)
	
	var trim_mat = StandardMaterial3D.new()
	trim_mat.albedo_color = box_color.lightened(0.35)
	trim_mat.roughness = 0.2
	top_trim_instance.material_override = trim_mat
	add_child(top_trim_instance)

func set_color(color: Color) -> void:
	box_color = color
	_apply_color()

func _apply_color() -> void:
	if material:
		material.albedo_color = box_color
	if top_trim_instance and top_trim_instance.material_override:
		var trim_mat = top_trim_instance.material_override as StandardMaterial3D
		trim_mat.albedo_color = box_color.lightened(0.35)

func drop(initial_velocity: Vector3, landing_y: float) -> void:
	state = BoxState.FALLING
	velocity = initial_velocity
	target_landing_y = landing_y

func _physics_process(delta: float) -> void:
	match state:
		BoxState.FALLING:
			velocity.y -= gravity * delta
			# Add slight air drag on horizontal momentum
			velocity.x = move_toward(velocity.x, 0.0, delta * 2.0)
			velocity.z = move_toward(velocity.z, 0.0, delta * 2.0)
			
			global_position += velocity * delta
			
			# Check if bottom of this box reaches the target landing height
			var current_bottom_y = global_position.y - (box_size.y * 0.5)
			if current_bottom_y <= target_landing_y:
				# Snap to exact surface level
				global_position.y = target_landing_y + (box_size.y * 0.5)
				landed.emit(self, true)
		
		BoxState.TOPPLING:
			velocity.y -= (gravity * 1.2) * delta
			global_position += velocity * delta
			rotate(topple_axis, topple_speed * delta)
			
			# Free when plunged far below
			if global_position.y < -15.0:
				queue_free()

func settle(is_perfect: bool) -> void:
	state = BoxState.LANDED
	velocity = Vector3.ZERO
	transform.basis = Basis.IDENTITY
	
	# Tactile squash & stretch impact bounce
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var squash_scale = Vector3(1.08, 0.82, 1.08)
	var normal_scale = Vector3.ONE
	
	scale = squash_scale
	tween.tween_property(self, "scale", normal_scale, 0.22)
	
	if is_perfect:
		_play_perfect_flash()

func start_topple(direction: Vector3) -> void:
	state = BoxState.TOPPLING
	topple_axis = direction.cross(Vector3.UP).normalized()
	if topple_axis.length_squared() < 0.001:
		topple_axis = Vector3.RIGHT
	
	velocity = Vector3(direction.x * 2.5, 1.5, direction.z * 2.5)
	topple_speed = 6.5

func _play_perfect_flash() -> void:
	# Golden flash emission pulse
	if material:
		material.emission_enabled = true
		material.emission = Color(1.0, 0.9, 0.4)
		material.emission_energy_multiplier = 2.0
		
		var tween = create_tween()
		tween.tween_property(material, "emission_energy_multiplier", 0.0, 0.4)
		tween.finished.connect(func(): material.emission_enabled = false)
