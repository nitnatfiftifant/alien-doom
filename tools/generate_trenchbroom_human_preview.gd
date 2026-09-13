extends SceneTree

func _init() -> void:
	var error := _write_preview(_build_human(), "res://models/editor/human_spawn.glb")
	if error == OK:
		error = _write_preview(_build_alien(), "res://models/editor/alien_spawn.glb")
	if error == OK:
		error = _write_preview(_build_nest(), "res://models/editor/nest.glb")
	if error != OK:
		push_error("Could not generate TrenchBroom previews: %s" % error_string(error))
		quit(1)
		return
	print("ALIEN_DOOM_EDITOR_PREVIEWS_OK textured=true forward=-Z")
	quit(0)

func _write_preview(root: Node3D, path: String) -> Error:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_scene(root, state)
	if error == OK:
		error = document.write_to_filesystem(state, path)
	root.free()
	return error

func _build_human() -> Node3D:
	var root := Node3D.new()
	root.name = "HumanSpawnPreview"
	_add_box(root, "Body", Vector3(0.55, 1.4, 0.35), Vector3(0.0, 0.95, 0.0), Color(0.32, 0.36, 0.42))
	_add_sphere(root, "Head", 0.25, Vector3(0.0, 1.85, 0.0), Color(0.78, 0.65, 0.48))
	_add_box(root, "ForwardShaft", Vector3(0.12, 0.12, 0.95), Vector3(0.0, 1.35, -0.65), Color(1.0, 0.28, 0.03))
	_add_arrow_head(root, 1.35, -1.25, Color(1.0, 0.65, 0.02))
	return root

func _build_alien() -> Node3D:
	var root := Node3D.new()
	root.name = "AlienSpawnPreview"
	_add_box(root, "CrawlerBody", Vector3(0.7, 0.42, 1.15), Vector3(0.0, 0.32, 0.0), Color(0.08, 0.32, 0.12))
	_add_sphere(root, "ForwardHead", 0.34, Vector3(0.0, 0.38, -0.65), Color(0.18, 0.75, 0.24))
	_add_box(root, "ForwardShaft", Vector3(0.1, 0.1, 0.7), Vector3(0.0, 0.72, -0.72), Color(0.5, 1.0, 0.08))
	_add_arrow_head(root, 0.72, -1.18, Color(0.75, 1.0, 0.08))
	return root

func _build_nest() -> Node3D:
	var root := Node3D.new()
	root.name = "NestPreview"
	_add_box(root, "NestBase", Vector3(1.55, 0.22, 1.55), Vector3(0.0, 0.11, 0.0), Color(0.28, 0.06, 0.08))
	_add_sphere(root, "NestCore", 0.58, Vector3(0.0, 0.42, 0.0), Color(0.58, 0.06, 0.12))
	_add_box(root, "NestSpineX", Vector3(1.75, 0.15, 0.18), Vector3(0.0, 0.32, 0.0), Color(0.82, 0.12, 0.16))
	_add_box(root, "NestSpineZ", Vector3(0.18, 0.15, 1.75), Vector3(0.0, 0.32, 0.0), Color(0.82, 0.12, 0.16))
	return root

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var image := Image.create_empty(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(color)
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.albedo_color = Color.WHITE
	material.roughness = 0.8
	return material

func _add_box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	instance.mesh = mesh
	instance.position = position
	parent.add_child(instance)

func _add_sphere(parent: Node3D, node_name: String, radius: float, position: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.material = _material(color)
	instance.mesh = mesh
	instance.position = position
	parent.add_child(instance)

func _add_arrow_head(parent: Node3D, height: float, forward: float, color: Color) -> void:
	var instance := MeshInstance3D.new()
	instance.name = "ForwardArrowHead"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 0.28
	mesh.height = 0.55
	mesh.radial_segments = 12
	mesh.material = _material(color)
	instance.mesh = mesh
	instance.rotation.x = -PI * 0.5
	instance.position = Vector3(0.0, height, forward)
	parent.add_child(instance)
