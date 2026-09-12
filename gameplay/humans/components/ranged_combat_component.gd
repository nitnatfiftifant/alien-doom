class_name RangedCombatComponent
extends Node

signal shot_fired

@export var actor: HumanController
@export var muzzle: Node3D
@export var damage := 12.0
@export var range := 18.0
@export var shot_interval := 0.65
var cooldown := 0.0

func tick(target: CreatureController, delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	if target == null or cooldown > 0.0: return
	var from := muzzle.global_position
	var query := PhysicsRayQueryParameters3D.create(from, target.global_position)
	query.exclude = [actor]
	var hit := muzzle.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.collider != target: return
	cooldown = shot_interval
	shot_fired.emit()
	target.health.apply_damage(damage, actor)
	(get_node("/root/NOISE") as NoiseBus).emit_noise(from, 1.0, actor)
