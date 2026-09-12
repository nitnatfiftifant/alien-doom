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
	assert((creature.collision_mask & 8) == 0, "Corpse can physically displace the creature")
	for part in corpse.ragdoll.bodies:
		assert((part.collision_mask & 2) == 0 and (part.collision_mask & 13) == 13, "Ragdoll must collide with world, humans and other corpses while ignoring creature impulses")
		assert(PhysicsServer3D.body_is_continuous_collision_detection_enabled(part.get_rid()), "Physical bone CCD is disabled")
		var part_shape := part.get_child(0) as CollisionShape3D
		assert(part_shape != null and part_shape.position.y > 0.0, "Physical bone shape is centred on its joint instead of covering the skinned limb")
	assert(corpse.ragdoll.simulator.has_node("Ragdoll_foot_l") and corpse.ragdoll.simulator.has_node("Ragdoll_foot_r"), "Feet lack floor collision bodies")
	var self_exceptions := corpse.ragdoll.bodies[0].get_collision_exceptions()
	assert(self_exceptions.size() == corpse.ragdoll.bodies.size() - 1, "Bones of one ragdoll can collide and fight their joints")
	var velocity_probe := corpse.ragdoll.bodies[0]
	velocity_probe.linear_velocity = Vector3(100, 0, 0)
	velocity_probe.angular_velocity = Vector3(0, 100, 0)
	corpse.ragdoll._physics_process(1.0 / 60.0)
	assert(velocity_probe.linear_velocity.length() <= corpse.ragdoll.maximum_linear_speed + 0.01, "Ragdoll linear speed safety limit is not applied")
	assert(velocity_probe.angular_velocity.length() <= corpse.ragdoll.maximum_angular_speed + 0.01, "Ragdoll angular speed safety limit is not applied")
	var lower_arm := corpse.ragdoll.simulator.get_node("Ragdoll_lowerarm_l") as PhysicalBone3D
	var upper_arm := corpse.ragdoll.simulator.get_node("Ragdoll_upperarm_l") as PhysicalBone3D
	var clavicle := corpse.ragdoll.simulator.get_node("Ragdoll_clavicle_l") as PhysicalBone3D
	assert(lower_arm != null and upper_arm != null and clavicle != null, "Continuous arm joint chain is incomplete")
	var upper_arm_parent_index := corpse.ragdoll.skeleton.get_bone_parent(corpse.ragdoll.skeleton.find_bone(upper_arm.bone_name))
	var lower_arm_parent_index := corpse.ragdoll.skeleton.get_bone_parent(corpse.ragdoll.skeleton.find_bone(lower_arm.bone_name))
	assert(corpse.ragdoll.skeleton.get_bone_name(lower_arm_parent_index) == upper_arm.bone_name, "Forearm skeleton parent is not simulated")
	assert(corpse.ragdoll.skeleton.get_bone_name(upper_arm_parent_index) == clavicle.bone_name, "Arm skeleton parent is not simulated")
	var pelvis := corpse.ragdoll.simulator.get_node("Ragdoll_pelvis") as PhysicalBone3D
	var pushed_part := corpse.ragdoll.bodies[0]
	creature.carry.camera.global_position = pushed_part.global_position + Vector3(0, 0, 2.0)
	creature.carry.camera.look_at(pushed_part.global_position + Vector3(0.3, 0, 0), Vector3.UP)
	creature.carry.begin_grab(creature)
	assert(creature.carry.carried != null, "Aim volume did not acquire a nearby physical bone")
	creature.carry.drop()
	pushed_part.global_position = creature.global_position + Vector3(0.4, 0.2, 0)
	creature.velocity = Vector3(5, 0, 0)
	creature.ragdoll_pusher.physics_step()
	await physics_frame
	assert(pushed_part.linear_velocity.x > 0.0, "Creature did not apply one-way push force to ragdoll")
	pushed_part.linear_velocity = Vector3.ZERO
	creature.carry.call("_begin_grab", pushed_part, pushed_part.global_position)
	assert(is_equal_approx(pelvis.gravity_scale, creature.carry.config.held_gravity_scale), "Grab did not reduce ragdoll gravity for vertical traversal")
	creature.carry.camera.global_position += Vector3(1.5, 0.5, 0)
	pelvis.linear_velocity = Vector3.ZERO
	for step in 12:
		creature.carry.physics_step(1.0 / 60.0)
		await physics_frame
	assert(creature.carry.get_movement_multiplier() < 1.0, "Dragging a corpse did not slow the creature")
	assert(creature.carry.ragdoll_bodies.size() == corpse.ragdoll.bodies.size(), "Spring pull did not acquire the complete ragdoll")
	assert(pushed_part.linear_velocity.length() > 0.0, "Spring did not pull the selected bone")
	assert(pelvis.linear_velocity.length() > 0.0, "Distributed spring did not move the corpse centre of mass")
	creature.carry.drop()
	assert(is_equal_approx(pelvis.gravity_scale, 1.0), "Dropping corpse did not restore ragdoll gravity")
	assert(pushed_part.angular_damp >= 4.0 and pushed_part.joint_type != PhysicalBone3D.JOINT_TYPE_NONE, "Ragdoll joints lack anatomical constraints or damping")
	corpse.ragdoll.sleep_linear_threshold = 1000.0
	corpse.ragdoll.sleep_angular_threshold = 1000.0
	corpse.ragdoll.sleep_after_seconds = 0.0
	corpse.ragdoll.freeze_after_seconds = 0.0
	corpse.ragdoll._physics_process(1.0 / 60.0)
	assert(corpse.ragdoll.is_frozen and PhysicsServer3D.body_get_mode(pelvis.get_rid()) == PhysicsServer3D.BODY_MODE_STATIC, "Settled ragdoll did not deactivate for Web optimization")
	corpse.ragdoll.wake()
	assert(not corpse.ragdoll.is_frozen and PhysicsServer3D.body_get_mode(pelvis.get_rid()) == PhysicsServer3D.BODY_MODE_RIGID, "Grab/push did not reactivate frozen ragdoll")
	print("ALIEN_DOOM_ACID_RAGDOLL_OK parts=%d" % corpse.ragdoll.bodies.size())
	root.queue_free()
	await process_frame
	await process_frame
	quit(0)
