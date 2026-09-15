extends SceneTree

var world: Node3D
var guard: HumanController
var creature: CreatureController
var final_head_forward := Vector3.ZERO

func _init() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(45.0).timeout.connect(func():
		push_error("Aim/projectile test timed out")
		quit(1)
	)
	world = Node3D.new()
	root.add_child(world)
	guard = (load("res://gameplay/humans/human.tscn") as PackedScene).instantiate() as HumanController
	guard.role = "Guard"
	world.add_child(guard)
	guard.set_physics_process(false)
	creature = (load("res://gameplay/player/creature.tscn") as PackedScene).instantiate() as CreatureController
	world.add_child(creature)
	creature.set_physics_process(false)
	var skeleton := guard.get_node("VisualRoot").find_child("Skeleton3D", true, false) as Skeleton3D
	skeleton.skeleton_updated.connect(func():
		final_head_forward = (skeleton.global_basis * skeleton.get_bone_global_pose(skeleton.find_bone("Head")).basis.z).normalized()
	)
	var weapon := guard.get_node("HumanWeaponComponent") as HumanWeaponComponent
	guard.stress.add_stress(100.0)
	for target_position in [Vector3(4, 1.5, 3), Vector3(-4, 1.5, -3), Vector3(0, 6, -3), Vector3(0, 0.4, -3), Vector3(0, 6, 0), Vector3(0, -3, 0)]:
		creature.position = target_position
		guard.awareness.track_creature(creature, true)
		for frame in 90:
			guard.aiming.tick(1.0 / 60.0)
			await physics_frame
			await process_frame
		var desired := (creature.global_position - weapon.muzzle.global_position).normalized()
		var barrel := -weapon.muzzle.global_basis.z.normalized()
		assert(barrel.dot(desired) > 0.995, "Gun barrel did not follow lateral/elevated/low target: %s" % target_position)
		var sensor := -guard.perception.global_basis.z.normalized()
		assert(final_head_forward.dot(sensor) > 0.995, "Head pose and visible vision cone disagree")
		var flat := (creature.position - guard.position).slide(Vector3.UP).normalized()
		if not flat.is_zero_approx():
			assert((-guard.global_basis.z).dot(flat) > 0.99, "Human body did not turn toward target")
		assert(guard.perception.evaluate_target(creature, 0.0), "Aimed perception cannot see elevated/low target")

	# A fresh target behind the barrel must not receive an instant shot.
	guard.combat.cooldown = 0.0
	creature.position = Vector3(0, 1.5, 5)
	guard.awareness.track_creature(creature, true)
	await physics_frame
	guard.combat.tick(creature, 1.0 / 60.0)
	assert(get_nodes_in_group("human_bullets").is_empty(), "Guard fired before turning the barrel")
	await _settle_aim(Vector3(0, 1.5, -6))
	var before := creature.health.current_health
	guard.combat.tick(creature, 1.0)
	assert(get_nodes_in_group("human_bullets").size() == 1, "Aligned guard did not launch a bullet")
	assert(creature.health.current_health == before, "Damage was applied before bullet travel")
	var bullet := get_nodes_in_group("human_bullets")[0] as HumanBulletProjectile
	assert(bullet.global_position.distance_to(weapon.muzzle.global_position) < 0.001, "Bullet did not leave the physical muzzle")
	# Evading after the shot must work: a bullet does not home onto its target.
	creature.position.x = 3.0
	for frame in 65: await physics_frame
	assert(creature.health.current_health == before, "Projectile homed onto an evading target")
	assert(get_nodes_in_group("human_bullets").is_empty(), "Missed bullet did not expire at its range")
	# Ordinary strafing at 4 m/s should not evade a 180 m/s bullet at six metres.
	await _settle_aim(Vector3(0, 1.5, -6))
	guard.combat.tick(creature, 1.0)
	assert(get_nodes_in_group("human_bullets").size() == 1, "Strafing scenario did not fire a projectile")
	for frame in 12:
		creature.position.x += 4.0 / 60.0
		await physics_frame
	assert(creature.health.current_health < before, "Fast bullet still misses ordinary close-range strafing")
	var damage_taken := before - creature.health.current_health
	assert(damage_taken >= creature.health.maximum_health * 0.5 and damage_taken <= creature.health.maximum_health * 0.6, "Random bullet damage outside 50–60%")
	before = creature.health.current_health

	# Thin cover inserted after launch catches even a fast-moving projectile.
	await _settle_aim(Vector3(0, 1.5, -6))
	guard.combat.tick(creature, 1.0)
	assert(get_nodes_in_group("human_bullets").size() == 1)
	bullet = get_nodes_in_group("human_bullets")[0] as HumanBulletProjectile
	bullet.speed = 600.0
	var wall := StaticBody3D.new()
	wall.position = Vector3(0, 1.5, -3)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 5, 0.02)
	collision.shape = box
	wall.add_child(collision)
	world.add_child(wall)
	for frame in 5: await physics_frame
	assert(creature.health.current_health == before, "Fast projectile passed through thin cover")
	assert(get_nodes_in_group("human_bullets").is_empty(), "Impact did not remove projectile")
	guard.combat.tick(creature, 1.0)
	assert(get_nodes_in_group("human_bullets").is_empty(), "Guard fired through solid cover")
	wall.queue_free()
	await physics_frame
	await _settle_aim(Vector3(0, 1.5, -25))
	guard.combat.tick(creature, 1.0)
	assert(get_nodes_in_group("human_bullets").is_empty(), "Guard fired beyond weapon range")
	# Loss of sight freezes remembered aim instead of following a hidden player.
	guard.awareness.creature_visible = false
	var remembered := guard.awareness.last_known_position
	creature.position = Vector3(10, 1.5, 0)
	for frame in 30:
		guard.aiming.tick(1.0 / 60.0)
		await physics_frame
	assert(guard.awareness.last_known_position == remembered, "Aim revealed a hidden target's new position")
	# Two actual impacts must kill even with a different maximum HP value.
	creature.health.configure(200.0)
	var deaths := {"count": 0}
	creature.health.died.connect(func(_source): deaths.count += 1)
	var rolled_damage: Array[float] = []
	creature.health.damaged.connect(func(amount, _source): rolled_damage.append(amount))
	for shot in 2:
		await _settle_aim(Vector3(0, 1.5, -6))
		guard.combat.tick(creature, 1.0)
		for frame in 8: await physics_frame
		assert(deaths.count == shot, "Player must survive the first hit and die on the second")
	assert(rolled_damage.size() == 2)
	for amount in rolled_damage:
		assert(amount >= 100.0 and amount <= 120.0, "Damage did not scale with maximum HP")
	guard.health.apply_damage(1000.0, creature)
	assert(not guard.aiming.modifier.active, "Procedural aim still fights the ragdoll after death")
	guard.combat.tick(creature, 1.0)
	assert(get_nodes_in_group("human_bullets").is_empty(), "Dead guard fired a projectile")
	print("ALIEN_DOOM_HUMAN_AIM_PROJECTILE_OK yaw_pitch=true muzzle=true travel=true dodge=true thin_wall=true range=true")
	world.queue_free()
	await process_frame
	quit(0)

func _settle_aim(position: Vector3) -> void:
	creature.position = position
	guard.awareness.track_creature(creature, true)
	for frame in 75:
		guard.aiming.tick(1.0 / 60.0)
		await physics_frame
		await process_frame
