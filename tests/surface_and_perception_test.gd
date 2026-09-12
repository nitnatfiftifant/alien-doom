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
	var camera_forward_after_corner := -creature.camera_pivot.global_basis.z
	assert(absf(camera_forward_after_corner.dot(Vector3.RIGHT)) < 0.15, "Corner smoothing twisted the camera sideways")
	var wall_normal := creature.motor.surface_up
	var wall_forward := creature.motor.surface_forward
	creature.motor.physics_step(Vector2.ZERO, false, true, 1.0 / 60.0)
	assert(creature.velocity.dot(wall_normal) > 10.0, "Wall jump lacks an outward launch")

	# Test Wall Climbing while Looking Downward (pitched camera must not reverse movement)
	creature.position = Vector3(0, 0.45, 0)
	creature.velocity = Vector3.ZERO
	creature.camera_pivot.rotation = Vector3.ZERO
	creature.camera_pivot.rotation.x = -0.4
	creature.motor.reset_orientation()
	for step in 38:
		creature.motor.physics_step(Vector2(0, 1), false, false, 1.0 / 60.0)
		await physics_frame
	assert(absf(creature.motor.surface_up.dot(Vector3.UP)) < 0.35, "Looking down prevented wall transition")
	assert(creature.global_position.y > 0.8, "Looking down prevented climbing up the wall")
	creature.camera_pivot.rotation = Vector3.ZERO

	# Test Floor Detach (Key C)
	creature.position = Vector3(0, 2.0, -1.875)
	creature.motor.surface_up = wall_normal
	creature.motor.attached = true
	creature.motor.is_airborne = false
	creature.motor.physics_step(Vector2.ZERO, false, false, 1.0 / 60.0, true)
	assert(creature.motor.is_airborne and creature.motor.surface_up.dot(Vector3.UP) > 0.9, "Floor detach (C) did not release adhesion or align upward")

	# Test Ceiling Adherence
	_add_box(root, Vector3(0, 5, 0), Vector3(8, 0.5, 8))
	creature.position = Vector3(0, 4.38, 0)
	creature.velocity = Vector3.ZERO
	creature.motor.surface_up = Vector3.DOWN
	creature.motor.surface_forward = Vector3.FORWARD
	creature.motor.attached = true
	creature.motor.is_airborne = false
	for step in 25:
		creature.motor.physics_step(Vector2(0, 1), false, false, 1.0 / 60.0)
		await physics_frame
	assert(creature.motor.attached and creature.motor.surface_up.dot(Vector3.DOWN) > 0.8, "Creature did not maintain attachment while crawling on ceiling")
	assert(creature.global_position.y > 4.35, "Creature fell from ceiling during crawl")

	# Test Ceiling Jump along camera view direction (not slamming down into floor)
	creature.position = Vector3(0, 4.38, 0)
	creature.velocity = Vector3.ZERO
	creature.motor.surface_up = Vector3.DOWN
	creature.motor.surface_forward = Vector3.FORWARD
	creature.global_basis = Basis(Vector3.LEFT, Vector3.DOWN, Vector3.BACK)
	creature.camera_pivot.rotation = Vector3.ZERO
	creature.motor.attached = true
	creature.motor.is_airborne = false
	creature.motor.jump_cooldown = 0.0
	creature.motor.physics_step(Vector2.ZERO, false, true, 1.0 / 60.0)
	assert(creature.velocity.dot(Vector3.FORWARD) > 10.0 and creature.velocity.y > -5.0, "Ceiling jump must leap along camera view direction rather than slamming to floor")

	# Test Proactive Mid-Air Orientation toward upcoming wall along camera look
	creature.position = Vector3(0, 1.5, -0.5)
	creature.velocity = Vector3(0, 0.5, -5.0)
	creature.global_basis = Basis.IDENTITY
	creature.camera_pivot.rotation = Vector3.ZERO
	creature.motor.reset_orientation()
	creature.motor.attached = false
	creature.motor.is_airborne = true
	creature.motor.jump_launch_timer = 0.0
	for step in 8:
		creature.motor.physics_step(Vector2.ZERO, false, false, 1.0 / 60.0)
		await physics_frame
	assert(creature.motor.surface_up.dot(Vector3(0, 0, 1)) > 0.45, "Mid-air orientation did not proactively turn toward wall ahead along look direction")

	# Test Automatic Midair Wall Latching without movement input
	creature.position = Vector3(0, 2.0, -2.15)
	creature.velocity = Vector3(0, 0, -2.0)
	creature.motor.attached = false
	creature.motor.is_airborne = true
	creature.motor.jump_cooldown = 0.0
	for step in 5:
		creature.motor.physics_step(Vector2.ZERO, false, false, 1.0 / 60.0)
		await physics_frame
	assert(creature.motor.attached, "Creature in midair did not automatically latch onto wall upon contact without WASD keys")

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

	# Test Inner Corner Stability: walking into corner transitions and stays stable without cyclic spinning
	creature.position = Vector3(0, 0.45, -1.5)
	creature.velocity = Vector3.ZERO
	creature.global_basis = Basis.IDENTITY
	creature.camera_pivot.rotation = Vector3.ZERO
	creature.motor.reset_orientation()
	for step in 20:
		creature.motor.physics_step(Vector2(0, 1), false, false, 1.0 / 60.0)
		await physics_frame
	assert(creature.motor.surface_up.dot(Vector3(0, 0, 1)) > 0.8, "Creature did not transition to wall when moving into corner")
	var stable_wall_up := creature.motor.surface_up
	for step in 15:
		creature.motor.physics_step(Vector2(0, 1), false, false, 1.0 / 60.0)
		await physics_frame
	assert(creature.motor.surface_up.dot(stable_wall_up) > 0.9, "Creature cyclically spun or jittered between corner surfaces")

	# Test Outer (Convex) Corner Traversal: climbing over wall top onto horizontal top surface
	creature.position = Vector3(0, 3.7, -1.875)
	creature.velocity = Vector3.ZERO
	creature.global_basis = Basis.looking_at(Vector3.UP, Vector3(0, 0, 1))
	creature.camera_pivot.rotation = Vector3.ZERO
	creature.motor.surface_up = Vector3(0, 0, 1)
	creature.motor.surface_forward = Vector3.UP
	creature.motor.attached = true
	creature.motor.is_airborne = false
	for step in 10:
		creature.motor.physics_step(Vector2(0, 1), false, false, 1.0 / 60.0)
		await physics_frame
	assert(creature.motor.attached, "Creature detached instead of wrapping around convex corner")
	assert(creature.global_position.y >= 3.9, "Creature fell while climbing convex corner")
	assert(creature.motor.surface_up.dot(Vector3.UP) > 0.8, "Creature did not wrap onto horizontal top surface of the wall")


	# Test Oblique Wall Climbing (approaching wall at an angle must not be rejected)
	creature.position = Vector3(0, 0.45, -1.8)
	creature.velocity = Vector3.ZERO
	creature.global_basis = Basis.IDENTITY
	creature.camera_pivot.rotation = Vector3.ZERO
	creature.motor.reset_orientation()
	for step in 25:
		# Diagonal input (W+D) into the wall at Z = -2.25
		creature.motor.physics_step(Vector2(0.6, 0.8), false, false, 1.0 / 60.0)
		await physics_frame
	assert(creature.motor.surface_up.dot(Vector3(0, 0, 1)) > 0.8, "Oblique approach was rejected instead of climbing wall")

	# A nearly tangential approach must still climb once the sphere physically
	# contacts the wall; only perfectly parallel seam contact is ignored.
	creature.position = Vector3(0, 0.45, -1.86)
	creature.velocity = Vector3.ZERO
	creature.global_basis = Basis.IDENTITY
	creature.camera_pivot.rotation = Vector3.ZERO
	creature.motor.reset_orientation()
	for step in 30:
		creature.motor.physics_step(Vector2(1.0, 0.02), false, false, 1.0 / 60.0)
		await physics_frame
		if creature.motor.surface_up.dot(Vector3(0, 0, 1)) > 0.8:
			break
	assert(creature.motor.surface_up.dot(Vector3(0, 0, 1)) > 0.8, "Shallow physical contact was rejected by an approach-angle threshold")

	# Test Unreachable Ceiling Jump (looking up at ceiling must not invert orientation if jump cannot reach it)
	creature.position = Vector3(0, 0.45, 0)
	creature.velocity = Vector3(0, 6.0, 0) # Weak jump impulse, ceiling is at 5.0m
	creature.motor.reset_orientation()
	creature.motor.attached = false
	creature.motor.is_airborne = true
	creature.motor.jump_launch_timer = 0.0
	creature.camera_pivot.rotation.x = 1.3 # Looking almost straight up at ceiling
	for step in 20:
		creature.motor.physics_step(Vector2.ZERO, false, false, 1.0 / 60.0)
		await physics_frame
	assert(creature.motor.surface_up.dot(Vector3.UP) > 0.8, "Unreachable ceiling caused camera to invert upside down in midair")

	# A head-first collision during jump recontact lockout must latch to a new
	# surface. Previously the collision was discarded and the stopped body fell.
	creature.global_basis = Basis.IDENTITY
	creature.camera_pivot.rotation = Vector3.ZERO
	creature.motor.reset_orientation()
	creature.position = Vector3(0, 3.85, 0)
	creature.velocity = Vector3(0, 10.0, 0)
	creature.motor.attached = false
	creature.motor.is_airborne = true
	creature.motor.jump_source_up = Vector3.UP
	creature.motor.jump_cooldown = 0.2
	for step in 8:
		creature.motor.physics_step(Vector2.ZERO, false, false, 1.0 / 60.0)
		await physics_frame
		if creature.motor.attached:
			break
	assert(creature.motor.attached and creature.motor.surface_up.dot(Vector3.DOWN) > 0.8, "Head-first collision during jump lockout did not attach to ceiling")

	# Opposite walls must use the camera-right hinge, never an arbitrary 180° axis.
	creature.global_basis = Basis.IDENTITY
	creature.camera_pivot.rotation = Vector3.ZERO
	creature.motor.surface_forward = Vector3.UP
	var opposite_wall_rotation := creature.motor._surface_rotation(Vector3.FORWARD, Vector3.BACK)
	assert((opposite_wall_rotation * Vector3.UP).dot(Vector3.DOWN) > 0.99, "Opposite-wall landing rotated the view toward the floor")

	# Perception is checked in a separate, unobstructed arrangement.
	creature.motor.reset_orientation()
	creature.camera_pivot.rotation = Vector3.ZERO
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
