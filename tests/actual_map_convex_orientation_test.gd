extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var level := (load("res://maps/ventilation_blockout.tscn") as PackedScene).instantiate()
	get_root().add_child(level)
	await physics_frame
	var creature := get_first_node_in_group("creature") as CreatureController
	assert(creature != null, "Actual map did not spawn creature")
	creature.set_physics_process(false)

	var left_world_floor := false
	var returned_to_world_floor := false
	for step in 430:
		creature.motor.physics_step(Vector2(0.0, 1.0), false, false, 1.0 / 60.0)
		await physics_frame
		if creature.motor.surface_up.dot(Vector3.UP) < 0.5:
			left_world_floor = true
		elif left_world_floor and creature.motor.surface_up.dot(Vector3.UP) > 0.98:
			returned_to_world_floor = true
			break

	assert(returned_to_world_floor, "Route did not complete convex floor-wall-ceiling-wall-floor cycle")
	assert(creature.motor.smooth_up.dot(Vector3.UP) > 0.9, "Visual up retained accumulated convex-corner roll on world floor")
	for settle_step in 30:
		creature.motor.physics_step(Vector2.ZERO, false, false, 1.0 / 60.0)
		await physics_frame
	assert(creature.global_basis.y.dot(Vector3.UP) > 0.98, "Camera remained rolled after returning to world floor")

	# Shallow final alignment must still reach the exact floor normal.
	creature.motor.surface_up = Vector3(0.1, 0.995, 0.0).normalized()
	creature.motor.smooth_up = creature.motor.surface_up
	creature.motor._align_surface_normal(Vector3.UP)
	assert(creature.motor.surface_up.dot(Vector3.UP) > 0.999, "Shallow bevel normal threshold prevented flat-floor alignment")
	print("ALIEN_DOOM_ACTUAL_MAP_CONVEX_ORIENTATION_OK")
	level.queue_free()
	await process_frame
	quit(0)
