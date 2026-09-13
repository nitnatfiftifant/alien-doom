class_name PerceptionComponent
extends Node3D

signal stimulus_detected(position: Vector3, strength: float, is_corpse: bool)

@export var owner_body: Node3D
@export var direct_view_distance := 14.0
@export var peripheral_distance := 8.0
@export var touch_distance := 1.2
@export var hearing_distance := 18.0
@export var direct_half_angle := 25.0
@export var peripheral_half_angle := 90.0

func _ready() -> void:
	(get_node("/root/NOISE") as NoiseBus).noise_emitted.connect(_on_noise)

func evaluate_target(target: Node3D, delta: float, is_corpse := false) -> bool:
	if target == null:
		return false
	var offset := target.global_position - global_position
	var distance := offset.length()
	if distance <= touch_distance and _has_line_of_sight(target.global_position, target):
		stimulus_detected.emit(target.global_position, 90.0 * delta, is_corpse)
		return true
	var angle := rad_to_deg((-global_basis.z).angle_to(offset.normalized()))
	if distance <= direct_view_distance and angle <= direct_half_angle and _has_line_of_sight(target.global_position, target):
		var proximity := 1.0 - clampf(distance / direct_view_distance, 0.0, 1.0)
		stimulus_detected.emit(target.global_position, lerpf(35.0, 130.0, proximity) * delta, is_corpse)
		return true
	elif distance <= peripheral_distance and angle <= peripheral_half_angle and _has_line_of_sight(target.global_position, target):
		stimulus_detected.emit(target.global_position, 18.0 * delta, is_corpse)
		return true
	return false

func _has_line_of_sight(target_position: Vector3, expected: Node3D = null) -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position, target_position)
	query.exclude = [owner_body]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return true
	if expected == null:
		return false
	var collider := result.collider as Node
	return collider == expected or (collider != null and expected.is_ancestor_of(collider))

func _on_noise(position: Vector3, loudness: float, source: Node) -> void:
	if source == owner_body:
		return
	var distance := global_position.distance_to(position)
	if distance > hearing_distance * loudness:
		return
	var occlusion := 1.0 if _has_line_of_sight(position) else 0.35
	var audible_range := maxf(hearing_distance * loudness, 0.01)
	var strength := loudness * occlusion * clampf(1.0 - distance / audible_range, 0.0, 1.0) * 30.0
	stimulus_detected.emit(position, maxf(strength, 0.0), false)
