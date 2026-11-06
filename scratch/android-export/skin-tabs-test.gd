extends SceneTree

func _initialize() -> void:
	call_deferred("_test")

func _check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		quit(1)

func _test() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var game = current_scene
	game.btn_skin.pressed.emit()
	await create_timer(0.5).timeout
	var themes = game.drawer_content.get_child(0)
	var palettes = game.drawer_content.get_child(1)
	var themes_tab = game._skin_tab_row.get_child(0)
	var palettes_tab = game._skin_tab_row.get_child(1)
	_check(themes.visible and not palettes.visible and themes_tab.button_pressed, "Themes should open first")
	_check(game.drawer_modal.size.y <= game.COMPACT_DRAWER_HEIGHT + 1, "Drawer grew taller")
	palettes_tab.button_pressed = true
	await process_frame
	_check(palettes.visible and not themes.visible and not themes_tab.button_pressed, "Palettes should show alone")
	_check(game.drawer_scroll.scroll_vertical == 0, "Palette scroll should start at top")
	themes_tab.button_pressed = true
	await process_frame
	_check(themes.visible and not palettes.visible and not palettes_tab.button_pressed, "Themes should show alone")
	_check(themes.find_child("EdgeStyle", true, false) != null, "Edge Style is missing")
	game.btn_challenge.pressed.emit()
	_check(game._skin_tab_row == null, "Skins tabs leaked into Challenges")
	game.btn_skin.pressed.emit()
	_check(game._skin_tab_row.get_child_count() == 2, "Reopened Skins has duplicate tabs")
	print("Skin tabs smoke test complete")
