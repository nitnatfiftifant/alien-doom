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
	var world_geometry_has_surface_metadata := false
	for collision in collisions:
		var collision_body := collision.get_parent() as CollisionObject3D
		if collision_body != null and collision_body.has_meta(&"func_godot_mesh_data"):
			var mesh_data: Dictionary = collision_body.get_meta(&"func_godot_mesh_data", {})
			if mesh_data.has("texture_names") and mesh_data.has("normals") and mesh_data.has("positions") and mesh_data.has("collision_shape_to_face_indices_map"):
				world_geometry_has_surface_metadata = true
				break
	if not world_geometry_has_surface_metadata:
		fail("World geometry lacks FuncGodot face metadata required by no-climb materials")
		return
	if not FileAccess.file_exists("res://textures/special/no_climb.png") or not ResourceLoader.exists("res://materials/special/no_climb.tres"):
		fail("No-climb TrenchBroom texture or Godot material is missing")
		return
	if alien_starts.size() != 1:
		fail("Current map must contain exactly one creature start, got %d" % alien_starts.size())
		return
	var human_definition := load("res://fgd/point/info_human_spawn.tres") as FuncGodotFGDPointClass
	var nest_definition := load("res://fgd/point/info_nest.tres") as FuncGodotFGDPointClass
	if human_definition == null or human_definition.scene_file == null or nest_definition == null or nest_definition.scene_file == null:
		fail("Human or nest TrenchBroom point class is not connected to a runtime scene")
		return
	var test_mat := load("res://materials/Industrial/PIPES.tres") as StandardMaterial3D
	if test_mat == null or test_mat.albedo_texture == null or test_mat.texture_filter != BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS:
		fail("Pixel material PIPES.tres is missing or improperly configured")
		return
	var test_brick := load("res://materials/Bricks/BIGBRICKS.tres") as StandardMaterial3D
	if test_brick == null or test_brick.albedo_texture == null:
		fail("Pixel material BIGBRICKS.tres is missing or improperly configured")
		return
	print("ALIEN_DOOM_FUNC_GODOT_INTEGRATION_OK meshes=%d collisions=%d placed_humans=%d placed_nests=%d pixel_materials_verified=true" % [meshes.size(), collisions.size(), humans.size(), nests.size()])
	root.queue_free()
	await process_frame
	await process_frame
	quit(0)

func fail(message: String) -> void:
	push_error(message)
	quit(1)
