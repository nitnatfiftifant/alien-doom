extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	_add_box(root, Vector3(0, -0.25, 0), Vector3(8, 0.5, 8))
	_add_box(root, Vector3(0, 2, -2.5), Vector3(8, 4, 0.5))
	var creature := (load("res://gameplay/player/creature.tscn") as PackedScene).instantiate() as CreatureController
	root.add_child(creature)
	creature.position = Vector3(0, 0.45, 0)
	creature.set_physics_process(false)
	await physics_frame
	var initial_forward := creature.motor.surface_forward
	for step in 20:
		creature.motor.physics_step(Vector2(1, 0), false, false, 1.0 / 60.0)
		await physics_frame
	assert(creature.motor.surface_forward.dot(initial_forward) > 0.99, "Strafing rotated the creature instead of moving sideways")
	creature.position = Vector3(0, 0.45, 0)
	creature.velocity = Vector3.ZERO
	creature.motor.reset_orientation()
	for step in 38:
		creature.motor.physics_step(Vector2(0, 1), false, false, 1.0 / 60.0)
		await physics_frame
	assert(absf(creature.motor.surface_up.dot(Vector3.UP)) < 0.35, "Creature did not transition from floor to vertical wall")
	assert(creature.global_position.y > 0.8, "Creature attached to wall but did not climb")
	var wall_normal := creature.motor.surface_up
	var wall_forward := creature.motor.surface_forward
	creature.motor.physics_step(Vector2.ZERO, false, true, 1.0 / 60.0)
	assert(creature.velocity.dot(wall_normal) > 12.0, "Wall jump lacks a sharp outward launch")
	assert(creature.velocity.dot(wall_forward) >= 3.0, "Directional jump momentum is missing")

	# Test Floor Detach (Key C)
	creature.position = Vector3(0, 2.0, -1.875)
	creature.motor.surface_up = wall_normal
	creature.motor.attached = true
	creature.motor.is_airborne = false
	creature.motor.physics_step(Vector2.ZERO, false, false, 1.0 / 60.0, true)
	assert(creature.motor.is_airborne and creature.motor.surface_up.dot(Vector3.UP) > 0.9, "Floor detach (C) did not release adhesion or align upward")

	# Test Ceiling Adherence
	_add_box(root, Vector3(0, 5, 0), Vector3(8, 0.5, 8))
	creature.position = Vector3(0, 4.65, 0)
	creature.velocity = Vector3.ZERO
	creature.motor.surface_up = Vector3.DOWN
	creature.motor.surface_forward = Vector3.FORWARD
	creature.motor.attached = true
	creature.motor.is_airborne = false
	for step in 40:
		creature.motor.physics_step(Vector2(0, 1), false, false, 1.0 / 60.0)
		await physics_frame
	assert(creature.motor.attached and creature.motor.surface_up.dot(Vector3.DOWN) > 0.8, "Creature did not maintain attachment while crawling on ceiling")
	assert(creature.global_position.y > 4.4, "Creature fell from ceiling during crawl")

	# Test Mid-air Upright Orientation and Landing
	creature.position = Vector3(0, 3.5, 0)
	creature.velocity = Vector3.ZERO
	creature.motor.surface_up = Vector3.DOWN
	creature.motor.attached = false
	creature.motor.is_airborne = true
	for step in 70:
		creature.motor.physics_step(Vector2.ZERO, false, false, 1.0 / 60.0)
		await physics_frame
	assert(creature.motor.surface_up.dot(Vector3.UP) > 0.9, "Airborne creature did not reorient right-side-up before or upon landing")
	assert(creature.global_position.y < 0.6, "Creature did not land on floor")

	# Test Inner Corner Anti-Jitter: walking parallel to wall along the floor seam
	creature.position = Vector3(0, 0.45, -2.1)
	creature.velocity = Vector3.ZERO
	creature.motor.reset_orientation()
	for step in 25:
		creature.motor.physics_step(Vector2(1, 0), false, false, 1.0 / 60.0)
		await physics_frame
	assert(creature.motor.surface_up.dot(Vector3.UP) > 0.95, "Inner corner jitter flipped surface normal while walking parallel")

	# Test Outer (Convex) Corner Traversal: climbing over wall top onto horizontal top surface
	creature.position = Vector3(0, 3.7, -1.875)
	creature.velocity = Vector3.ZERO
	creature.global_basis = Basis.looking_at(Vector3.UP, Vector3(0, 0, 1))
	creature.camera_pivot.rotation = Vector3.ZERO
	creature.motor.surface_up = Vector3(0, 0, 1)
	creature.motor.surface_forward = Vector3.UP
	creature.motor.attached = true
	creature.motor.is_airborne = false
	for step in 12:
		creature.motor.physics_step(Vector2(0, 1), false, false, 1.0 / 60.0)
		await physics_frame
	assert(creature.motor.attached, "Creature detached instead of wrapping around convex corner")
	assert(creature.global_position.y >= 3.9, "Creature fell while climbing convex corner")
	assert(creature.motor.surface_up.dot(Vector3.UP) > 0.8, "Creature did not wrap onto horizontal top surface of the wall")

	# Perception is checked in a separate, unobstructed arrangement.
	creature.motor.reset_orientation()
	creature.global_position = Vector3(0, 0.45, 0)
	creature.global_basis = Basis.IDENTITY

	var human := (load("res://gameplay/humans/human.tscn") as PackedScene).instantiate() as HumanController
	root.add_child(human)
	human.position = Vector3(0, 0.45, 3)
	human.look_at(creature.global_position, Vector3.UP)
	await physics_frame
	for step in 90:
		human.perception.evaluate_target(creature, 1.0 / 60.0)
	assert(human.stress.state >= StressComponent.State.CAUTIOUS, "Visible creature did not raise human stress")
	print("ALIEN_DOOM_SURFACE_PERCEPTION_OK wall_up=%s stress=%.1f" % [creature.motor.surface_up, human.stress.value])
	root.queue_free()
	await process_frame
	await process_frame
	quit(0)

func _add_box(parent: Node3D, position: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = position
	body.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
