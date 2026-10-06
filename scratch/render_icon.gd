extends SceneTree

func _init():
	var full_path = ProjectSettings.globalize_path("res://icon.svg")
	var img = Image.load_from_file(full_path)
	if img != null:
		var icon_path = ProjectSettings.globalize_path("res://icon.png")
		img.save_png(icon_path)
		print("Saved icon.png (", img.get_width(), "x", img.get_height(), ")")

		var img_192 = Image.new()
		img_192.copy_from(img)
		img_192.resize(192, 192, Image.INTERPOLATE_LANCZOS)
		var icon_192_path = ProjectSettings.globalize_path("res://icon_192.png")
		img_192.save_png(icon_192_path)
		print("Saved icon_192.png (192x192)")
	else:
		print("IMAGE_NULL")
	quit()
