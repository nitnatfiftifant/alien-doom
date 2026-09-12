class_name CarryComponent
extends Node

@export var camera: Camera3D
@export var holder: Node3D
@export var reach := 2.0
@export var spring_strength := 95.0
@export var damping := 18.0
@export var maximum_force := 850.0
@export var break_distance := 4.5
@export_range(0.1, 1.0) var movement_multiplier := 0.55
var carried: PhysicalBone3D
var grab_local_point := Vector3.ZERO

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
	if hit.collider is PhysicalBone3D and hit.collider.is_in_group("corpse_ragdoll_parts"):
		carried = hit.collider as PhysicalBone3D
		grab_local_point = carried.to_local(hit.position)

func physics_step(delta: float) -> void:
	if carried == null or not is_instance_valid(carried):
		carried = null
		return
	var grab_world := carried.to_global(grab_local_point)
	var displacement := holder.global_position - grab_world
	if displacement.length() > break_distance:
		drop()
		return
	var point_velocity := carried.linear_velocity + carried.angular_velocity.cross(grab_world - carried.global_position)
	var force := (displacement * spring_strength - point_velocity * damping).limit_length(maximum_force)
	carried.apply_impulse(force * delta, grab_world - carried.global_position)

func drop() -> void:
	if carried == null: return
	carried = null

func get_movement_multiplier() -> float:
	return movement_multiplier if carried != null else 1.0

func consume_carried() -> Node3D:
	if carried == null: return null
	var corpse := carried.get_parent()
	while corpse != null and not corpse.is_in_group("corpses"):
		corpse = corpse.get_parent()
	carried = null
	return corpse as Node3D
