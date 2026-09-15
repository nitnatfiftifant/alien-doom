class_name HumanAimComponent
extends Node

@export var actor: HumanController
@export var visual_root: Node3D
@export var perception: PerceptionComponent
@export var weapon: HumanWeaponComponent
@export_range(1.0, 30.0) var tracking_speed := 10.0
@export_range(0.0, 85.0) var maximum_head_yaw := 70.0
@export_range(0.0, 89.0) var maximum_pitch := 89.0

var aim_point := Vector3.ZERO
var modifier: HumanAimModifier

func _ready() -> void:
	var skeleton := visual_root.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return
	modifier = HumanAimModifier.new()
	modifier.name = "HumanAimModifier"
	modifier.aim = self
	aim_point = perception.global_position - actor.global_basis.z * perception.direct_view_distance
	skeleton.add_child(modifier)

func tick(delta: float) -> void:
	if not actor.is_guard() or actor.is_in_group("corpses"):
		perception.rotation = Vector3.ZERO
		return
	var remembered := actor.awareness.last_stimulus_kind != HumanAwarenessMemory.StimulusKind.NONE
	var tracking := remembered and actor.stress.state != StressComponent.State.CALM
	var distance := perception.direct_view_distance
	var local_direction := Vector3.FORWARD
	if tracking:
		# Track remembered observations, never a hidden target's live position.
		var target := actor.awareness.last_known_position
		actor.face_position(target, delta)
		var offset := target - perception.global_position
		distance = maxf(offset.length(), 0.5)
		if not offset.is_zero_approx():
			local_direction = actor.global_basis.orthonormalized().inverse() * offset.normalized()
	var yaw := clampf(atan2(-local_direction.x, -local_direction.z), -deg_to_rad(maximum_head_yaw), deg_to_rad(maximum_head_yaw))
	var pitch := clampf(asin(clampf(local_direction.y, -1.0, 1.0)), -deg_to_rad(maximum_pitch), deg_to_rad(maximum_pitch))
	var desired := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	perception.basis = perception.basis.orthonormalized().slerp(desired, 1.0 - exp(-tracking_speed * delta))
	aim_point = perception.global_position - perception.global_basis.z * distance
