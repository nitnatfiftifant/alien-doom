class_name SurfaceClimbPolicy
extends Node

## Texture/material path assigned to non-climbable brush faces in TrenchBroom.
@export var no_climb_texture: StringName = &"special/no_climb"
@export_range(-1.0, 1.0, 0.01) var face_normal_match_threshold := 0.9
@export_range(0.001, 0.5, 0.001, "or_greater") var face_plane_tolerance := 0.12

func is_hit_climbable(hit: Dictionary, collision_mask: int) -> bool:
	if hit.is_empty():
		return false
	return is_contact_climbable(
		hit.get("collider", null),
		int(hit.get("shape", -1)),
		hit.get("position", Vector3.ZERO),
		hit.get("normal", Vector3.ZERO),
		collision_mask
	)

func is_contact_climbable(collider: Object, shape_index: int, world_position: Vector3, world_normal: Vector3, collision_mask: int) -> bool:
	var collision_object := collider as CollisionObject3D
	if collision_object == null or (collision_object.collision_layer & collision_mask) == 0:
		return false
	return not is_contact_no_climb(collider, shape_index, world_position, world_normal)

func is_contact_no_climb(collider: Object, shape_index: int, world_position: Vector3, world_normal: Vector3) -> bool:
	var collision_object := collider as CollisionObject3D
	if collision_object == null:
		return false
	if collision_object.get_meta(&"no_climb", false):
		return true
	if shape_index < 0 or not collision_object.has_meta(&"func_godot_mesh_data"):
		return false
	return _func_godot_face_has_no_climb(collision_object, shape_index, world_position, world_normal)

func _func_godot_face_has_no_climb(collider: CollisionObject3D, shape_index: int, world_position: Vector3, world_normal: Vector3) -> bool:
	var data: Dictionary = collider.get_meta(&"func_godot_mesh_data", {})
	var texture_names: Array = data.get("texture_names", [])
	var texture_indices: PackedInt32Array = data.get("textures", PackedInt32Array())
	var normals: PackedVector3Array = data.get("normals", PackedVector3Array())
	var positions: PackedVector3Array = data.get("positions", PackedVector3Array())
	var shape_faces: Dictionary = data.get("collision_shape_to_face_indices_map", {})
	if texture_names.is_empty() or texture_indices.is_empty() or normals.is_empty() or positions.is_empty():
		return false
	var owner_id := collider.shape_find_owner(shape_index)
	if owner_id < 0:
		return false
	var shape_node := collider.shape_owner_get_owner(owner_id) as CollisionShape3D
	if shape_node == null:
		return false
	var face_indices: PackedInt32Array = shape_faces.get(String(shape_node.name), PackedInt32Array())
	if face_indices.is_empty():
		return false
	var local_position := collider.to_local(world_position)
	var local_normal := (collider.global_basis.inverse() * world_normal).normalized()
	var best_index := -1
	var best_plane_distance := INF
	var best_normal_dot := -INF
	for face_index in face_indices:
		if face_index < 0 or face_index >= normals.size() or face_index >= positions.size():
			continue
		var face_normal := normals[face_index].normalized()
		var normal_dot := face_normal.dot(local_normal)
		var plane_distance := absf(face_normal.dot(local_position - positions[face_index]))
		if normal_dot < face_normal_match_threshold or plane_distance > face_plane_tolerance:
			continue
		if normal_dot > best_normal_dot or (is_equal_approx(normal_dot, best_normal_dot) and plane_distance < best_plane_distance):
			best_index = face_index
			best_normal_dot = normal_dot
			best_plane_distance = plane_distance
	if best_index < 0 or best_index >= texture_indices.size():
		return false
	var texture_index := texture_indices[best_index]
	if texture_index < 0 or texture_index >= texture_names.size():
		return false
	return _texture_matches(texture_names[texture_index])

func _texture_matches(texture_name: Variant) -> bool:
	var actual := String(texture_name).replace("\\", "/").to_lower()
	var expected := String(no_climb_texture).replace("\\", "/").to_lower()
	return actual == expected or actual.get_file() == expected.get_file()
