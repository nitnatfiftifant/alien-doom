class_name CarryComponent
extends Node

@export var camera: Camera3D
@export var holder: Node3D
@export var reach := 2.0
var carried: Node3D

func toggle(owner_body: Node) -> void:
	if carried:
		drop()
		return
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position - camera.global_basis.z * reach)
	query.exclude = [owner_body]
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return
	var candidate := hit.collider as Node3D
	if candidate and candidate.has_method("interact"):
		candidate.call("interact", owner_body)
		return
	if candidate == null or not candidate.is_in_group("corpses"): return
	carried = candidate
	carried.reparent(holder, true)
	carried.position = Vector3.ZERO
	carried.set_physics_process(false)

func drop() -> void:
	if carried == null: return
	carried.reparent(holder.get_tree().current_scene, true)
	carried = null

func consume_carried() -> Node3D:
	var result := carried
	carried = null
	return result
