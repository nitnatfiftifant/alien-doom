class_name RangedCombatComponent
extends Node

signal shot_fired

@export var actor: HumanController
@export var weapon: HumanWeaponComponent
@export var projectile_scene: PackedScene
@export var damage := 12.0
@export var range := 18.0
@export var shot_interval := 0.65
@export var projectile_speed := 180.0
@export_range(0.5, 15.0) var aim_tolerance_degrees := 4.0
var cooldown := 0.0

func tick(target: CreatureController, delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	if not is_instance_valid(target) or cooldown > 0.0 or not actor.is_guard() or actor.is_in_group("corpses"):
		return
	if weapon.muzzle == null or projectile_scene == null or not actor.awareness.creature_visible:
		return
	var muzzle := weapon.muzzle
	var from := muzzle.global_position
	var offset := target.global_position - from
	if offset.length() > range or offset.is_zero_approx():
		return
	var direction := -muzzle.global_basis.z.normalized()
	if direction.dot(offset.normalized()) < cos(deg_to_rad(aim_tolerance_degrees)):
		return
	# The ray only authorizes firing. Damage is dealt later by a travelling bullet.
	var query := PhysicsRayQueryParameters3D.create(from, target.global_position)
	query.exclude = [actor]
	query.hit_from_inside = true
	var hit := muzzle.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.collider != target: return
	# The barrel cannot shoot through cover by protruding out of the far side.
	var clearance := PhysicsRayQueryParameters3D.create(actor.perception.global_position, from, 1 | 8)
	clearance.exclude = [actor]
	clearance.hit_from_inside = true
	if not actor.get_world_3d().direct_space_state.intersect_ray(clearance).is_empty():
		return
	cooldown = shot_interval
	var projectile := projectile_scene.instantiate() as HumanBulletProjectile
	actor.get_parent().add_child(projectile)
	projectile.launch(from, direction, actor, damage, range, projectile_speed)
	shot_fired.emit()
	(get_node("/root/NOISE") as NoiseBus).emit_noise(from, 1.0, actor)
