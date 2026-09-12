@tool
extends SceneTree

const SCENE_PATH := "res://maps/ventilation_blockout.tscn"

func _init() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		push_error("Cannot load %s" % SCENE_PATH)
		quit(1)
		return
	var scene_root := packed.instantiate()
	var map := scene_root.get_node("FuncGodotMap") as FuncGodotMap
	map.build()
	_set_owner_recursive(map, scene_root)
	var output := PackedScene.new()
	var pack_error := output.pack(scene_root)
	if pack_error != OK:
		push_error("Could not pack map scene: %s" % error_string(pack_error))
		quit(1)
		return
	var save_error := ResourceSaver.save(output, SCENE_PATH)
	if save_error != OK:
		push_error("Could not save map scene: %s" % error_string(save_error))
		quit(1)
		return
	print("ALIEN_DOOM_MAP_SCENE_BAKED_OK children=%d" % map.get_child_count())
	scene_root.free()
	quit(0)

func _set_owner_recursive(node: Node, scene_owner: Node) -> void:
	for child in node.get_children():
		child.owner = scene_owner
		# Keep FuncGodot point-class scenes as scene instances. Flattening their
		# descendants creates stale overrides whenever a gameplay scene changes.
		if child.scene_file_path.is_empty():
			_set_owner_recursive(child, scene_owner)
