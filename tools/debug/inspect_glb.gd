extends SceneTree
## Prints the surfaces/materials Godot imported for a GLB: godot --headless -s tools/debug/inspect_glb.gd -- res://path.glb

func _init() -> void:
	var path: String = OS.get_cmdline_user_args()[0]
	var inst := (load(path) as PackedScene).instantiate()
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh
		for i in m.get_surface_count():
			var mat := m.surface_get_material(i)
			var info := "%s surf %d verts=%d mat=%s" % [mi.name, i, m.surface_get_array_len(i), mat.resource_name if mat else "null"]
			if mat is BaseMaterial3D:
				info += " albedo=%s" % (mat as BaseMaterial3D).albedo_color
			print(info)
	quit()
