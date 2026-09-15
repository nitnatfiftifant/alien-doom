class_name CarryComponent
extends Node

@export var camera: Camera3D
@export var holder: Node3D
@export var config: Resource
var carried: PhysicalBone3D
var grab_local_point := Vector3.ZERO
var hold_distance := 1.5
var ragdoll_bodies: Array[PhysicalBone3D] = []
var original_gravity_scales: Dictionary = {}

func begin_grab(owner_body: Node) -> void:
	if carried != null: return
	if config == null: return
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position - camera.global_basis.z * config.reach, config.acquisition_mask)
	query.exclude = [owner_body]
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	var candidate := hit.get("collider") as Node3D
	if candidate and candidate.has_method("interact"):
		candidate.call("interact", owner_body)
		return
	var grab_body := candidate as PhysicalBone3D
	if grab_body == null or not grab_body.is_in_group("corpse_ragdoll_parts"):
		grab_body = _find_near_aim_body(owner_body)
	if grab_body != null:
		var hit_position: Vector3 = hit.get("position", grab_body.global_position)
		_begin_grab(grab_body, hit_position if candidate == grab_body else grab_body.global_position)

func physics_step(delta: float) -> void:
	if carried == null or not is_instance_valid(carried):
		drop()
		return
	var grab_world := carried.to_global(grab_local_point)
	if config == null: drop(); return
	var target_position: Vector3 = camera.global_position - camera.global_basis.z * hold_distance
	if target_position.distance_to(grab_world) > config.break_distance:
		drop()
		return
	var centre_velocity := Vector3.ZERO
	var total_mass := 0.0
	for body in ragdoll_bodies:
		if body == null or not is_instance_valid(body): continue
		centre_velocity += body.linear_velocity * body.mass
		total_mass += body.mass
	if total_mass <= 0.0: return
	centre_velocity /= total_mass
	var error: Vector3 = target_position - grab_world
	var acceleration: Vector3 = (error * config.spring_stiffness - centre_velocity * config.spring_damping).limit_length(config.maximum_acceleration)
	var distributed_acceleration: Vector3 = acceleration * config.distributed_pull_ratio
	for body in ragdoll_bodies:
		if body != null and is_instance_valid(body):
			body.apply_central_impulse(distributed_acceleration * body.mass * delta)
	var point_velocity := carried.linear_velocity + carried.angular_velocity.cross(grab_world - carried.global_position)
	var point_acceleration: Vector3 = (error * config.spring_stiffness - point_velocity * config.spring_damping).limit_length(config.maximum_acceleration)
	carried.apply_impulse(point_acceleration * carried.mass * (1.0 - config.distributed_pull_ratio) * delta, grab_world - carried.global_position)

func drop() -> void:
	for body in ragdoll_bodies:
		if body != null and is_instance_valid(body) and original_gravity_scales.has(body):
			body.gravity_scale = float(original_gravity_scales[body])
	carried = null
	ragdoll_bodies.clear()
	original_gravity_scales.clear()

func get_movement_multiplier() -> float:
	return config.movement_multiplier if carried != null and config != null else 1.0

func consume_carried() -> Node3D:
	if carried == null: return null
	var corpse := carried.get_parent()
	while corpse != null and not corpse.is_in_group("corpses"):
		corpse = corpse.get_parent()
	drop()
	return corpse as Node3D

func _begin_grab(body: PhysicalBone3D, world_point: Vector3) -> void:
	_wake_ragdoll(body)
	carried = body
	grab_local_point = body.to_local(world_point)
	hold_distance = clampf(camera.global_position.distance_to(world_point), config.minimum_hold_distance, config.maximum_hold_distance)
	ragdoll_bodies.clear()
	original_gravity_scales.clear()
	for sibling in body.get_parent().get_children():
		if sibling is PhysicalBone3D:
			var ragdoll_body := sibling as PhysicalBone3D
			ragdoll_bodies.append(ragdoll_body)
			original_gravity_scales[ragdoll_body] = ragdoll_body.gravity_scale
			ragdoll_body.gravity_scale = config.held_gravity_scale

func _wake_ragdoll(body: PhysicalBone3D) -> void:
	var current: Node = body
	while current != null:
		if current is HumanController:
			(current as HumanController).ragdoll.wake()
			return
		current = current.get_parent()

func _find_near_aim_body(owner_body: Node) -> PhysicalBone3D:
	var ray_origin := camera.global_position
	var ray_direction := -camera.global_basis.z.normalized()
	var best: PhysicalBone3D
	var best_distance := INF
	for candidate in get_tree().get_nodes_in_group("corpse_ragdoll_parts"):
		var body := candidate as PhysicalBone3D
		if body == null: continue
		var offset := body.global_position - ray_origin
		var along := offset.dot(ray_direction)
		if along < 0.0 or along > config.reach: continue
		var radial_distance := (offset - ray_direction * along).length()
		if radial_distance > config.aim_radius or along >= best_distance: continue
		# Stop slightly before the physical bone. A ray ending at the centre of a
		# corpse lying on the floor often reports that floor at the endpoint and
		# incorrectly rejects an otherwise visible grab target.
		var body_distance := ray_origin.distance_to(body.global_position)
		var endpoint_margin := minf(0.12, body_distance * 0.25)
		var occlusion_target := body.global_position + (ray_origin - body.global_position).normalized() * endpoint_margin
		var occlusion := PhysicsRayQueryParameters3D.create(ray_origin, occlusion_target, 1)
		occlusion.exclude = [owner_body]
		if not camera.get_world_3d().direct_space_state.intersect_ray(occlusion).is_empty(): continue
		best = body
		best_distance = along
	return best
