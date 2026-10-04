extends Node3D
class_name StackBox

enum BoxState { ATTACHED, FALLING, LANDED, TOPPLING }

var state: BoxState = BoxState.ATTACHED
var box_size: Vector3 = Vector3(2.4, 0.8, 2.4)
var velocity: Vector3 = Vector3.ZERO
var gravity: float = 38.0

# Target landing height (y coordinate of top face of the box below)
var target_landing_y: float = 0.0

# Hierarchy roots for decoupled animation
# squash_root has origin at bottom face so squashes ground naturally
var squash_root: Node3D
# tilt_root has origin at center of mass so banks and rotates around center
var tilt_root: Node3D

# Visual instances
var mesh_instance: MeshInstance3D
var top_trim_instance: MeshInstance3D
var core_gem_instance: MeshInstance3D
var corner_accents_instance: MeshInstance3D

# Materials
var material: StandardMaterial3D
var trim_material: StandardMaterial3D
var gem_material: StandardMaterial3D
var corner_material: StandardMaterial3D

# Particle FX
var trail_particles: CPUParticles3D
var drop_particles: CPUParticles3D

# Dynamics
var topple_axis: Vector3 = Vector3.RIGHT
var topple_speed: float = 8.0
var box_color: Color = Color(0.2, 0.6, 0.95)

var settle_tween: Tween = null
var flash_tween: Tween = null
var absorb_tween: Tween = null

signal landed(box: Node3D, hit_target: bool)

func _init() -> void:
	_build_mesh()

func _ready() -> void:
	if not mesh_instance:
		_build_mesh()
	_apply_color()

func _build_mesh() -> void:
	if squash_root:
		return
	
	# Root 1: Squash root anchored at the BOTTOM face of the box
	squash_root = Node3D.new()
	squash_root.name = "SquashRoot"
	squash_root.position = Vector3(0, -box_size.y * 0.5, 0)
	add_child(squash_root)
	
	# Root 2: Tilt root centered at the geometric center of mass
	tilt_root = Node3D.new()
	tilt_root.name = "TiltRoot"
	tilt_root.position = Vector3(0, box_size.y * 0.5, 0)
	squash_root.add_child(tilt_root)
	
	# 1. Main Cube Body
	mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = box_size
	mesh_instance.mesh = box_mesh
	
	material = StandardMaterial3D.new()
	material.shading_mode = StandardMaterial3D.SHADING_MODE_PER_PIXEL
	material.roughness = 0.22
	material.metallic = 0.16
	material.clearcoat_enabled = true
	material.clearcoat = 0.45
	material.clearcoat_roughness = 0.2
	material.rim_enabled = true
	material.rim = 0.65
	material.rim_tint = 0.4
	material.albedo_color = box_color
	mesh_instance.material_override = material
	tilt_root.add_child(mesh_instance)
	
	# 2. Sleek Top Surface Chamfer Trim Frame
	top_trim_instance = MeshInstance3D.new()
	var trim_mesh = BoxMesh.new()
	trim_mesh.size = Vector3(box_size.x * 0.94, 0.035, box_size.z * 0.94)
	top_trim_instance.mesh = trim_mesh
	top_trim_instance.position = Vector3(0, box_size.y * 0.5 + 0.015, 0)
	
	trim_material = StandardMaterial3D.new()
	trim_material.albedo_color = box_color.lightened(0.42)
	trim_material.roughness = 0.18
	trim_material.metallic = 0.25
	trim_material.emission_enabled = true
	trim_material.emission = box_color.lightened(0.3)
	trim_material.emission_energy_multiplier = 0.45
	top_trim_instance.material_override = trim_material
	tilt_root.add_child(top_trim_instance)
	
	# 3. Inner Center Energy Rune / Diamond Core Inset
	core_gem_instance = MeshInstance3D.new()
	var gem_mesh = BoxMesh.new()
	gem_mesh.size = Vector3(0.56, 0.045, 0.56)
	core_gem_instance.mesh = gem_mesh
	core_gem_instance.position = Vector3(0, box_size.y * 0.5 + 0.025, 0)
	core_gem_instance.rotation.y = deg_to_rad(45.0)
	
	gem_material = StandardMaterial3D.new()
	gem_material.albedo_color = box_color.lightened(0.65)
	gem_material.roughness = 0.15
	gem_material.metallic = 0.4
	gem_material.emission_enabled = true
	gem_material.emission = box_color.lightened(0.55)
	gem_material.emission_energy_multiplier = 0.9
	core_gem_instance.material_override = gem_material
	tilt_root.add_child(core_gem_instance)
	
	# 4. Corner Bevel Bracket Accents
	corner_accents_instance = MeshInstance3D.new()
	var corner_mesh = BoxMesh.new()
	corner_mesh.size = Vector3(box_size.x * 0.99, 0.025, box_size.z * 0.99)
	corner_accents_instance.mesh = corner_mesh
	corner_accents_instance.position = Vector3(0, box_size.y * 0.5 + 0.005, 0)
	
	corner_material = StandardMaterial3D.new()
	corner_material.albedo_color = box_color.darkened(0.2)
	corner_material.roughness = 0.4
	corner_accents_instance.material_override = corner_material
	tilt_root.add_child(corner_accents_instance)
	
	# 5. Glider Particle Trail (Emits while sliding)
	trail_particles = CPUParticles3D.new()
	trail_particles.name = "TrailParticles"
	trail_particles.emitting = true
	trail_particles.amount = 18
	trail_particles.lifetime = 0.45
	trail_particles.local_coords = false
	trail_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	trail_particles.emission_box_extents = Vector3(box_size.x * 0.35, 0.15, box_size.z * 0.35)
	trail_particles.gravity = Vector3(0, -1.5, 0)
	trail_particles.initial_velocity_min = 0.2
	trail_particles.initial_velocity_max = 0.8
	trail_particles.scale_amount_min = 0.08
	trail_particles.scale_amount_max = 0.16
	trail_particles.color = box_color.lightened(0.4)
	
	var p_mesh = BoxMesh.new()
	p_mesh.size = Vector3(0.09, 0.09, 0.09)
	var p_mat = StandardMaterial3D.new()
	p_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	p_mat.albedo_color = box_color.lightened(0.4)
	p_mesh.material = p_mat
	trail_particles.mesh = p_mesh
	add_child(trail_particles)
	
	# 6. Drop Speed Sparks (Emits while falling)
	drop_particles = CPUParticles3D.new()
	drop_particles.name = "DropParticles"
	drop_particles.emitting = false
	drop_particles.amount = 16
	drop_particles.lifetime = 0.28
	drop_particles.local_coords = false
	drop_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	drop_particles.emission_box_extents = Vector3(box_size.x * 0.4, 0.1, box_size.z * 0.4)
	drop_particles.gravity = Vector3(0, 8.0, 0)
	drop_particles.initial_velocity_min = 1.0
	drop_particles.initial_velocity_max = 2.5
	drop_particles.scale_amount_min = 0.06
	drop_particles.scale_amount_max = 0.14
	drop_particles.color = box_color.lightened(0.6)
	drop_particles.mesh = p_mesh
	add_child(drop_particles)

func set_color(color: Color) -> void:
	box_color = color
	_apply_color()

func _apply_color() -> void:
	var h = box_color.h
	var s = box_color.s
	var v = box_color.v
	
	# Main body: rich, saturated jewel finish
	if material:
		material.albedo_color = box_color
	
	# Top trim: vivid, radiant neon frame that retains pure saturation without chalky white washout
	if trim_material:
		var trim_col = Color.from_hsv(h, clamp(s * 0.85, 0.45, 0.85), min(v * 1.15, 1.0))
		trim_material.albedo_color = trim_col
		trim_material.emission = Color.from_hsv(h, clamp(s * 0.9, 0.55, 0.95), 1.0)
		trim_material.emission_energy_multiplier = 0.45
	
	# Center core gem: radiant luminous crystal core
	if gem_material:
		var gem_col = Color.from_hsv(h, clamp(s * 0.52, 0.28, 0.70), 1.0)
		gem_material.albedo_color = gem_col
		gem_material.emission = Color.from_hsv(h, clamp(s * 0.65, 0.4, 0.85), 1.0)
		gem_material.emission_energy_multiplier = 0.9
	
	# Corner bevel accents: deep rich tone preserving hue
	if corner_material:
		var corner_col = Color.from_hsv(h, clamp(s * 1.05, 0.7, 1.0), max(v * 0.68, 0.35))
		corner_material.albedo_color = corner_col
	
	if trail_particles:
		var trail_c = Color.from_hsv(h, clamp(s * 0.75, 0.4, 0.8), 1.0)
		trail_particles.color = trail_c
		if trail_particles.mesh and trail_particles.mesh is BoxMesh:
			var pm = (trail_particles.mesh as BoxMesh).material as StandardMaterial3D
			if pm:
				pm.albedo_color = trail_c
	
	if drop_particles:
		drop_particles.color = Color.from_hsv(h, clamp(s * 0.6, 0.3, 0.7), 1.0)

# Called continuously while attached to slider
func update_slider_motion(delta: float, velocity_factor: float, axis_index: int, is_aligned: bool, hover_time: float) -> void:
	if state != BoxState.ATTACHED or not is_instance_valid(tilt_root):
		return
	
	# 1. Dynamic Banking / Tilt into direction of motion
	var max_bank_angle = deg_to_rad(6.8)
	if axis_index == 0:
		# Moving along X axis: roll around Z axis
		var target_rot_z = -velocity_factor * max_bank_angle
		tilt_root.rotation.z = lerp(tilt_root.rotation.z, target_rot_z, delta * 14.0)
		tilt_root.rotation.x = lerp(tilt_root.rotation.x, 0.0, delta * 14.0)
	else:
		# Moving along Z axis: pitch around X axis
		var target_rot_x = velocity_factor * max_bank_angle
		tilt_root.rotation.x = lerp(tilt_root.rotation.x, target_rot_x, delta * 14.0)
		tilt_root.rotation.z = lerp(tilt_root.rotation.z, 0.0, delta * 14.0)
	
	# 2. Aerodynamic momentum squash & stretch
	var speed_abs = abs(velocity_factor)
	var stretch_val = 1.0 + (speed_abs * 0.05)
	var compress_val = 1.0 - (speed_abs * 0.025)
	if axis_index == 0:
		squash_root.scale = Vector3(stretch_val, 1.0, compress_val)
	else:
		squash_root.scale = Vector3(compress_val, 1.0, stretch_val)
	
	# 3. Continuous slow core gem rotation
	if is_instance_valid(core_gem_instance):
		core_gem_instance.rotation.y += delta * 1.8
	
	# 4. Alignment & Hover Breathing Emissive Flare
	if is_aligned:
		# Sweet-spot: pulse bright anticipation flare
		if gem_material:
			gem_material.emission_energy_multiplier = lerp(gem_material.emission_energy_multiplier, 2.2 + sin(hover_time * 16.0) * 0.4, delta * 16.0)
		if trim_material:
			trim_material.emission_energy_multiplier = lerp(trim_material.emission_energy_multiplier, 1.3, delta * 14.0)
		if is_instance_valid(core_gem_instance):
			core_gem_instance.scale = Vector3.ONE * (1.14 + sin(hover_time * 14.0) * 0.08)
	else:
		# Idle gentle breathing
		if gem_material:
			var breath = 0.75 + sin(hover_time * 5.0) * 0.25
			gem_material.emission_energy_multiplier = lerp(gem_material.emission_energy_multiplier, breath, delta * 8.0)
		if trim_material:
			trim_material.emission_energy_multiplier = lerp(trim_material.emission_energy_multiplier, 0.45, delta * 8.0)
		if is_instance_valid(core_gem_instance):
			core_gem_instance.scale = Vector3.ONE * (1.0 + sin(hover_time * 4.0) * 0.04)

func drop(initial_velocity: Vector3, landing_y: float) -> void:
	state = BoxState.FALLING
	velocity = initial_velocity
	target_landing_y = landing_y
	
	# Switch particle states
	if is_instance_valid(trail_particles):
		trail_particles.emitting = false
	if is_instance_valid(drop_particles):
		drop_particles.emitting = true
	
	# Cleanly straighten banking rotation as it drops
	if is_instance_valid(tilt_root):
		var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(tilt_root, "rotation", Vector3.ZERO, 0.12)

func _physics_process(delta: float) -> void:
	match state:
		BoxState.FALLING:
			velocity.y -= gravity * delta
			# Add slight air drag on horizontal momentum
			velocity.x = move_toward(velocity.x, 0.0, delta * 2.0)
			velocity.z = move_toward(velocity.z, 0.0, delta * 2.0)
			
			global_position += velocity * delta
			
			# Aerodynamic vertical fall stretch (elongate along Y, compress along X/Z)
			var fall_speed = abs(velocity.y)
			var stretch_y = clamp(1.0 + (fall_speed * 0.01), 1.0, 1.25)
			var squish_xz = 1.0 / sqrt(stretch_y)
			if is_instance_valid(squash_root):
				squash_root.scale = Vector3(squish_xz, stretch_y, squish_xz)
			
			# Check if bottom of this box reaches the target landing height
			var current_bottom_y = global_position.y - (box_size.y * 0.5)
			if current_bottom_y <= target_landing_y:
				# Snap to exact surface level
				global_position.y = target_landing_y + (box_size.y * 0.5)
				landed.emit(self, true)
		
		BoxState.TOPPLING:
			velocity.y -= (gravity * 1.3) * delta
			global_position += velocity * delta
			if is_instance_valid(tilt_root):
				tilt_root.rotate(topple_axis, topple_speed * delta)
			
			# Free when plunged far below
			if global_position.y < -15.0:
				queue_free()

func settle(is_perfect: bool) -> void:
	state = BoxState.LANDED
	velocity = Vector3.ZERO
	if is_instance_valid(tilt_root):
		tilt_root.rotation = Vector3.ZERO
	
	if is_instance_valid(drop_particles):
		drop_particles.emitting = false
	if is_instance_valid(trail_particles):
		trail_particles.emitting = false
	
	# Spawn expanding impact shockwave ring on contact plane
	_spawn_impact_ring(is_perfect)
	
	# Juicy multi-stage elastic squash & stretch spring
	if settle_tween:
		settle_tween.kill()
	settle_tween = create_tween()
	
	var squash_scale = Vector3(1.26, 0.62, 1.26) if not is_perfect else Vector3(1.34, 0.54, 1.34)
	var stretch_scale = Vector3(0.88, 1.18, 0.88) if not is_perfect else Vector3(0.84, 1.24, 0.84)
	var bounce_scale = Vector3(1.05, 0.96, 1.05)
	
	# Stage 1: Fast juicy pancake squash onto surface (anchored at bottom)
	settle_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	settle_tween.tween_property(squash_root, "scale", squash_scale, 0.07)
	
	# Stage 2: Energetic spring rebound stretch
	settle_tween.chain().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	settle_tween.tween_property(squash_root, "scale", stretch_scale, 0.11)
	
	# Stage 3: Second micro-wobble
	settle_tween.chain().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	settle_tween.tween_property(squash_root, "scale", bounce_scale, 0.08)
	
	# Stage 4: Settle to rest
	settle_tween.chain().tween_property(squash_root, "scale", Vector3.ONE, 0.07)
	
	if is_perfect:
		_play_perfect_flash()
	else:
		_play_land_flash()

func absorb_impact() -> void:
	# Called on previous box when a new box lands on top
	if state != BoxState.LANDED or not is_instance_valid(squash_root):
		return
	if absorb_tween:
		absorb_tween.kill()
	absorb_tween = create_tween()
	absorb_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	absorb_tween.tween_property(squash_root, "scale", Vector3(1.06, 0.92, 1.06), 0.06)
	absorb_tween.chain().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	absorb_tween.tween_property(squash_root, "scale", Vector3.ONE, 0.12)

func flash_sympathetic() -> void:
	# Emissive ripple when a combo cascade occurs
	if trim_material:
		var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		trim_material.emission_energy_multiplier = 1.6
		tw.tween_property(trim_material, "emission_energy_multiplier", 0.45, 0.3)

func start_topple(direction: Vector3) -> void:
	state = BoxState.TOPPLING
	if is_instance_valid(drop_particles):
		drop_particles.emitting = false
	if is_instance_valid(trail_particles):
		trail_particles.emitting = false
	
	topple_axis = direction.cross(Vector3.UP).normalized()
	if topple_axis.length_squared() < 0.001:
		topple_axis = Vector3.RIGHT
	
	velocity = Vector3(direction.x * 2.8, 1.8, direction.z * 2.8)
	topple_speed = 7.5

func _play_land_flash() -> void:
	if trim_material:
		trim_material.emission_energy_multiplier = 1.2
		var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(trim_material, "emission_energy_multiplier", 0.45, 0.25)

func _play_perfect_flash() -> void:
	# Brilliant golden emission burst & gem spin
	if flash_tween:
		flash_tween.kill()
	flash_tween = create_tween().set_parallel(true)
	
	if material:
		material.emission_enabled = true
		material.emission = Color(1.0, 0.92, 0.45)
		material.emission_energy_multiplier = 2.4
		flash_tween.tween_property(material, "emission_energy_multiplier", 0.0, 0.45)
	
	if trim_material:
		trim_material.emission = Color(1.0, 0.95, 0.6)
		trim_material.emission_energy_multiplier = 3.0
		flash_tween.tween_property(trim_material, "emission_energy_multiplier", 0.45, 0.5)
	
	if gem_material:
		gem_material.emission = Color(1.0, 0.98, 0.7)
		gem_material.emission_energy_multiplier = 3.5
		flash_tween.tween_property(gem_material, "emission_energy_multiplier", 0.85, 0.5)
	
	if is_instance_valid(core_gem_instance):
		flash_tween.tween_property(core_gem_instance, "rotation:y", core_gem_instance.rotation.y + TAU, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	flash_tween.chain().tween_callback(func():
		if material:
			material.emission_enabled = false
		_apply_color()
	)

func _spawn_impact_ring(is_perfect: bool) -> void:
	var parent_node = get_parent()
	if not parent_node:
		return
	
	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 1.05
	torus.outer_radius = 1.2
	torus.rings = 28
	torus.ring_segments = 8
	ring.mesh = torus
	
	var ring_mat = StandardMaterial3D.new()
	ring_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var col = Color(1.0, 0.9, 0.35, 0.9) if is_perfect else Color(box_color.r, box_color.g, box_color.b, 0.75)
	ring_mat.albedo_color = col
	ring.material_override = ring_mat
	
	ring.scale = Vector3(0.4, 0.08, 0.4)
	parent_node.add_child(ring)
	ring.global_position = Vector3(global_position.x, target_landing_y + 0.03, global_position.z)
	
	var tw = ring.create_tween().set_parallel(true)
	var max_scale = Vector3(2.5, 0.08, 2.5) if is_perfect else Vector3(1.9, 0.08, 1.9)
	tw.tween_property(ring, "scale", max_scale, 0.32).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring_mat, "albedo_color:a", 0.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(ring.queue_free)
