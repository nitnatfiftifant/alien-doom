extends SceneTree

func _init() -> void:
	var packed := load("res://gameplay/humans/assets/ual1_human.glb") as PackedScene
	if packed == null:
		push_error("UAL2 human asset could not be loaded")
		quit(1)
		return
	var instance := packed.instantiate()
	get_root().add_child(instance)
	for skeleton in instance.find_children("*", "Skeleton3D", true, false):
		var names: Array[String] = []
		for bone_index in (skeleton as Skeleton3D).get_bone_count():
			names.append((skeleton as Skeleton3D).get_bone_name(bone_index))
		print("HUMAN_SKELETON bones=%d names=%s" % [names.size(), ",".join(names)])
	for player in instance.find_children("*", "AnimationPlayer", true, false):
		var animations := (player as AnimationPlayer).get_animation_list()
		var useful: PackedStringArray = []
		for name in animations:
			var lower := str(name).to_lower()
			if "idle" in lower or "walk" in lower or "run" in lower or "death" in lower or "damage" in lower or "shoot" in lower:
				useful.append(name)
		print("HUMAN_ANIMATIONS total=%d useful=%s" % [animations.size(), ",".join(useful)])
		print("HUMAN_ANIMATIONS_ALL %s" % ",".join(animations))
	print("HUMAN_ASSET_NODES meshes=%d players=%d" % [instance.find_children("*", "MeshInstance3D", true, false).size(), instance.find_children("*", "AnimationPlayer", true, false).size()])
	for mesh_node in instance.find_children("*", "MeshInstance3D", true, false):
		print("HUMAN_MESH_AABB %s" % (mesh_node as MeshInstance3D).get_aabb())
	instance.queue_free()
	await process_frame
	quit(0)
