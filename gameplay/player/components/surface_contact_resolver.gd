class_name SurfaceContactResolver
extends Node

@export var body: CharacterBody3D
@export var climb_policy: SurfaceClimbPolicy
@export_flags_3d_physics var collision_mask := 1
@export_group("Virtual legs")
@export_range(4, 12, 1) var radial_leg_count := 8
@export_range(5.0, 85.0, 1.0) var leg_fan_angle_degrees := 62.0
@export_range(0.1, 2.0, 0.05) var leg_reach := 1.15
@export_range(0.0, 0.5, 0.01) var probe_origin_radius := 0.2
@export_range(0.0, 0.8, 0.01) var movement_look_ahead := 0.2
@export_range(0.0, 1.0, 0.01) var normal_continuity_weight := 0.25

# Kept as world-space data so animation/IK components can consume the same
# contacts without knowing anything about SurfaceMotor.
var contacts: Array[Dictionary] = []
var probe_samples: Array[Dictionary] = []

func sample_support(surface_up: Vector3, surface_forward: Vector3, movement_direction: Vector3) -> Dictionary:
	contacts.clear()
	probe_samples.clear()
	if body == null or not body.is_inside_tree():
		return {}
	var up := surface_up.normalized()
	if up.is_zero_approx():
		up = Vector3.UP
	var forward := movement_direction.slide(up).normalized()
	if forward.is_zero_approx():
		forward = surface_forward.slide(up).normalized()
	if forward.is_zero_approx():
		forward = _perpendicular_to(up)
	var right := forward.cross(up).normalized()
	var down := -up
	var fan_angle := deg_to_rad(leg_fan_angle_degrees)
	var space := body.get_world_3d().direct_space_state
	_probe(space, down, forward, up)
	for leg_index in radial_leg_count:
		var radial_angle := TAU * float(leg_index) / float(radial_leg_count)
		var radial := (forward * cos(radial_angle) + right * sin(radial_angle)).normalized()
		var direction := (down * cos(fan_angle) + radial * sin(fan_angle)).normalized()
		_probe(space, direction, forward, up)
	if contacts.is_empty():
		return {}
	contacts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.score) > float(b.score))
	var selected_index := int(contacts[0].get("probe_index", -1))
	if selected_index >= 0 and selected_index < probe_samples.size():
		probe_samples[selected_index]["selected"] = true
	return contacts[0]

func get_contacts() -> Array[Dictionary]:
	return contacts.duplicate(true)

func get_probe_samples() -> Array[Dictionary]:
	return probe_samples.duplicate(true)

func _probe(space: PhysicsDirectSpaceState3D, direction: Vector3, movement_forward: Vector3, current_up: Vector3) -> void:
	var origin := body.global_position + direction * probe_origin_radius
	var target := body.global_position + direction * leg_reach + movement_forward * movement_look_ahead
	var query := PhysicsRayQueryParameters3D.create(origin, target, collision_mask)
	query.exclude = [body]
	var hit := space.intersect_ray(query)
	if not hit.is_empty() and climb_policy != null and not climb_policy.is_hit_climbable(hit, collision_mask):
		hit.clear()
	var sample := {
		"name": "leg_%02d" % probe_samples.size(),
		"category": "leg",
		"start": origin,
		"end": target,
		"hit": not hit.is_empty(),
		"position": hit.get("position", target),
		"normal": hit.get("normal", Vector3.ZERO),
		"collider": hit.get("collider", null),
		"selected": false,
	}
	probe_samples.append(sample)
	if hit.is_empty():
		return
	var normal: Vector3 = (hit.normal as Vector3).normalized()
	var distance := body.global_position.distance_to(hit.position)
	var proximity := 1.0 - clampf(distance / leg_reach, 0.0, 1.0)
	var continuity := maxf(0.0, normal.dot(current_up))
	hit["score"] = proximity + continuity * normal_continuity_weight
	hit["leg_direction"] = direction
	hit["probe_index"] = probe_samples.size() - 1
	contacts.append(hit)

func _perpendicular_to(normal: Vector3) -> Vector3:
	var axis := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
	return axis.slide(normal).normalized()
