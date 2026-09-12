extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var grate := AcidGrate.new()
	grate.position = Vector3(0, 0.5, -2.0)
	var grate_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 1, 0.2)
	grate_shape.shape = box
	grate.add_child(grate_shape)
	root.add_child(grate)
	var projectile := (load("res://gameplay/player/acid_projectile.tscn") as PackedScene).instantiate() as AcidProjectile
	root.add_child(projectile)
	projectile.position = Vector3(0, 0.5, 0)
	projectile.launch(Vector3.FORWARD, null, 35.0, 12.0)
	for step in 20:
		await physics_frame
	assert(not is_instance_valid(grate), "Acid projectile hit did not dissolve the grate")

	var creature := (load("res://gameplay/player/creature.tscn") as PackedScene).instantiate() as CreatureController
	root.add_child(creature)
	creature.position = Vector3.ZERO
	creature.set_physics_process(false)
	var corpse := (load("res://gameplay/humans/human.tscn") as PackedScene).instantiate() as HumanController
	root.add_child(corpse)
	corpse.position = Vector3(0.5, 0, 0)
	corpse.set_physics_process(false)
	corpse.ragdoll.activate()
	await physics_frame
	assert((creature.collision_mask & 8) == 0, "Corpse can still physically push the creature")
	for part in corpse.ragdoll.bodies:
		assert((part.collision_mask & 2) == 0 and (part.collision_mask & 1) != 0, "Ragdoll collision must ignore creature and retain walls")
	var pushed_part := corpse.ragdoll.bodies[0]
	pushed_part.global_position = creature.global_position + Vector3(0.4, 0.2, 0)
	creature.velocity = Vector3(5, 0, 0)
	creature.ragdoll_pusher.physics_step()
	await physics_frame
	assert(pushed_part.linear_velocity.x > 0.0, "Creature did not apply one-way push force to ragdoll")
	pushed_part.linear_velocity = Vector3.ZERO
	creature.carry.carried = pushed_part
	creature.carry.grab_local_point = Vector3.ZERO
	creature.carry.holder.global_position = pushed_part.global_position + Vector3(1.5, 0.5, 0)
	creature.carry.physics_step(1.0 / 60.0)
	await physics_frame
	assert(creature.carry.get_movement_multiplier() < 1.0, "Dragging a corpse did not slow the creature")
	assert(pushed_part.linear_velocity.length() > 0.0, "Point grab did not pull the selected physical bone")
	creature.carry.drop()
	assert(pushed_part.angular_damp >= 4.0 and pushed_part.joint_type != PhysicalBone3D.JOINT_TYPE_NONE, "Ragdoll joints lack anatomical constraints or damping")
	print("ALIEN_DOOM_ACID_RAGDOLL_OK parts=%d" % corpse.ragdoll.bodies.size())
	root.queue_free()
	await process_frame
	await process_frame
	quit(0)
