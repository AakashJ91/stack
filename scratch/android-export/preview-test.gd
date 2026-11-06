extends SceneTree

func _initialize() -> void:
	call_deferred("_test")

func _test() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var game = current_scene
	for button in [game.btn_skin, game.btn_challenge]:
		button.pressed.emit()
		await create_timer(1.6).timeout
		var rim: MeshInstance3D = game.pedestal_rim
		var half_rim := rim.get_aabb().size * 0.5
		var corner := rim.to_global(Vector3(half_rim.x, -half_rim.y, half_rim.z))
		var gap: float = game.drawer_modal.get_global_transform_with_canvas().origin.y - game.camera.unproject_position(corner).y
		print(game.active_ribbon_tab, " gap: ", gap)
		if gap <= 0.0:
			quit(1)
			return
	game.btn_home.pressed.emit()
	if not is_equal_approx(game.target_camera_y, game.base_camera_pivot_y + game.HOME_PLATFORM_CAMERA_OFFSET):
		quit(1)
		return
	quit()
