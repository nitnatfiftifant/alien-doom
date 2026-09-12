class_name CreatureAbilities
extends Node

signal acid_cooldown_changed(remaining: float, duration: float)

@export var camera: Camera3D
@export var bite_visual: BiteOverlay
@export var acid_projectile_scene: PackedScene
@export var combat_config: CreatureCombatConfig
var acid_remaining := 0.0
var bite_animating := false

func tick(delta: float) -> void:
	acid_remaining = maxf(0.0, acid_remaining - delta)
	acid_cooldown_changed.emit(acid_remaining, combat_config.acid_cooldown)

func bite(instigator: Node) -> void:
	if bite_animating: return
	_animate_bite()
	_hit(camera.global_position, -camera.global_basis.z, combat_config.bite_range, combat_config.bite_damage, instigator, false)

func spit_acid(instigator: Node) -> bool:
	if acid_remaining > 0.0:
		return false
	acid_remaining = combat_config.acid_cooldown
	var projectile := acid_projectile_scene.instantiate() as AcidProjectile
	var projectile_parent := camera.get_tree().current_scene
	if projectile_parent == null:
		projectile_parent = camera.get_tree().root
	projectile_parent.add_child(projectile)
	projectile.global_position = camera.global_position - camera.global_basis.z * 0.45
	projectile.launch(-camera.global_basis.z, instigator, combat_config.acid_damage, combat_config.acid_range)
	_animate_spit()
	(get_node("/root/NOISE") as NoiseBus).emit_noise(camera.global_position, 0.65, instigator)
	return true

func _animate_bite() -> void:
	bite_animating = true
	bite_visual.play_bite()
	await bite_visual.animation_finished
	bite_visual.play(&"idle")
	bite_animating = false

func _animate_spit() -> void:
	var tween := create_tween()
	tween.tween_property(bite_visual, "modulate", Color(0.45, 1.0, 0.25), 0.06)
	tween.tween_property(bite_visual, "modulate", Color.WHITE, 0.14)

func _hit(origin: Vector3, direction: Vector3, distance: float, damage: float, instigator: Node, acid: bool) -> void:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * distance)
	query.exclude = [instigator]
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var target := hit.collider as Node
	if acid and target.has_method("dissolve_by_acid"):
		target.call("dissolve_by_acid")
	var health := target.find_child("HealthComponent", true, false) as HealthComponent
	if health:
		var applied_damage := damage
		if not acid:
			applied_damage = calculate_bite_damage(target, instigator)
		health.apply_damage(applied_damage, instigator)

func calculate_bite_damage(target: Node3D, instigator: Node) -> float:
	if target == null or not instigator is Node3D:
		return combat_config.bite_damage
	var target_forward := -target.global_basis.z
	target_forward.y = 0.0
	var to_attacker := (instigator as Node3D).global_position - target.global_position
	to_attacker.y = 0.0
	if target_forward.is_zero_approx() or to_attacker.is_zero_approx():
		return combat_config.bite_damage
	var approach_dot := target_forward.normalized().dot(to_attacker.normalized())
	if approach_dot <= combat_config.back_bite_dot_threshold:
		return combat_config.bite_damage * combat_config.back_bite_multiplier
	return combat_config.bite_damage
