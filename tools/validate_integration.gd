extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var scene := load("res://maps/ventilation_blockout.tscn") as PackedScene
	if scene == null:
		fail("Could not load the canonical map scene")
		return
	var root := scene.instantiate()
	get_root().add_child(root)
	var map := root.get_node_or_null("FuncGodotMap") as FuncGodotMap
	if map == null:
		fail("FuncGodotMap node is missing")
		return
	map.build()
	var meshes := map.find_children("*", "MeshInstance3D", true, false)
	var collisions := map.find_children("*", "CollisionShape3D", true, false)
	var alien_starts := map.find_children("*", "CreatureController", true, false)
	var humans := map.find_children("*", "HumanController", true, false)
	var nests := map.find_children("*", "CreatureNest", true, false)
	if meshes.is_empty() or collisions.is_empty():
		fail("Map did not produce render and collision geometry")
		return
	if alien_starts.size() != 1 or humans.size() != 2 or nests.size() != 1:
		fail("Custom entity pipeline is incomplete: starts=%d humans=%d nests=%d" % [alien_starts.size(), humans.size(), nests.size()])
		return
	var test_mat := load("res://materials/Industrial/PIPES.tres") as StandardMaterial3D
	if test_mat == null or test_mat.albedo_texture == null or test_mat.texture_filter != BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS:
		fail("Pixel material PIPES.tres is missing or improperly configured")
		return
	var test_brick := load("res://materials/Bricks/BIGBRICKS.tres") as StandardMaterial3D
	if test_brick == null or test_brick.albedo_texture == null:
		fail("Pixel material BIGBRICKS.tres is missing or improperly configured")
		return
	print("ALIEN_DOOM_FUNC_GODOT_INTEGRATION_OK meshes=%d collisions=%d pixel_materials_verified=true" % [meshes.size(), collisions.size()])
	root.queue_free()
	await process_frame
	await process_frame
	quit(0)

func fail(message: String) -> void:
	push_error(message)
	quit(1)
