extends SceneTree
## Builds a contact sheet from screenshots: godot --headless --path . --script tools/contact_sheet.gd -- <prefix> <out> [cols]
## Each tile is the full frame scaled to 480 px wide with its file name burnt in by order.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix: String = args[0] if args.size() > 0 else "vm_"
	var out: String = args[1] if args.size() > 1 else "sheet.png"
	var cols := int(args[2]) if args.size() > 2 else 4
	var dir := ProjectSettings.globalize_path("res://tools/screens")
	var files: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.begins_with(prefix) and f.ends_with(".png"):
			files.append(f)
	files.sort()
	var tw := 480
	var th := 270
	var rows := ceili(files.size() / float(cols))
	var sheet := Image.create(tw * cols, th * rows, false, Image.FORMAT_RGB8)
	for i in files.size():
		var img := Image.load_from_file(dir + "/" + files[i])
		img.convert(Image.FORMAT_RGB8)
		img.resize(tw, th, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(img, Rect2i(0, 0, tw, th), Vector2i((i % cols) * tw, (i / cols) * th))
	sheet.save_png(dir + "/" + out)
	print("sheet ", files.size(), " -> ", out)
	quit()
