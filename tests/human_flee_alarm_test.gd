extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(30.0).timeout.connect(func():
		push_error("Flee/alarm test timed out")
		quit(1)
	)
	var world := Node3D.new()
	root.add_child(world)
	var worker := _spawn(world, "Worker", Vector3.ZERO)
	var guard := _spawn(world, "Guard", Vector3(12, 0, 0))
	var far_guard := _spawn(world, "Guard", Vector3(40, 0, 0))
	var deaf_guard := _spawn(world, "Guard", Vector3(0, 0, 12))
	deaf_guard.perception.hearing_distance = 1.0
	var creature := (load("res://gameplay/player/creature.tscn") as PackedScene).instantiate() as CreatureController
	creature.position = Vector3(0, 1.65, -3)
	world.add_child(creature)
	creature.set_physics_process(false)
	var noise := root.get_node("NOISE") as NoiseBus
	var counts := {"alarms": 0}
	noise.alarm_emitted.connect(func(_position, _loudness, _source, _threat): counts.alarms += 1)
	await physics_frame
	noise.emit_noise(worker.perception.global_position + Vector3(0, 0, 3), 1.0, creature)
	worker.alarm.tick(0.1)
	assert(worker.alarm.indicator.visible and worker.alarm.indicator.text == "?", "Heard noise must show a suspicion marker")
	assert(counts.alarms == 0, "Civilian raised a confirmed-sighting alarm from noise alone")
	assert(worker.perception.evaluate_target(creature, 1.0))
	worker.awareness.track_creature(creature, true)
	worker.alarm.tick(0.1)
	assert(worker.alarm.indicator.text == "!" and worker.alarm.confirmed_sighting, "Seeing the monster did not show the alarm icon")
	assert(counts.alarms == 1 and worker.alarm.voice.playing, "Civilian did not emit the audible alarm")
	assert(guard.stress.state == StressComponent.State.ALERT, "Guard outside stress-sharing radius did not hear the alarm")
	assert(guard.awareness.last_known_position == creature.position, "Guard investigated the worker instead of the reported monster")
	assert(far_guard.stress.state != StressComponent.State.ALERT and deaf_guard.stress.state != StressComponent.State.ALERT, "Alarm ignored listener hearing range")
	for frame in 10: worker.alarm.tick(0.1)
	assert(counts.alarms == 1, "Civilian alarm repeated every frame")

	# Reproduce an initialized navigation map that contains no walkable regions.
	var empty_map := NavigationServer3D.map_create()
	NavigationServer3D.map_set_active(empty_map, true)
	NavigationServer3D.map_force_update(empty_map)
	worker.navigation.set_navigation_map(empty_map)
	var before := worker.global_position.distance_to(creature.global_position)
	for frame in 45:
		worker.state_machine.physics_update(1.0 / 60.0)
		worker.move_and_slide()
		await physics_frame
	var away := (worker.position - creature.position).slide(Vector3.UP).normalized()
	assert(worker.velocity.dot(away) > 0.0 and worker.position.distance_to(creature.position) > before + 1.0, "Civilian runs toward the monster when navigation has no path")
	guard.position = worker.position + away * 3.0
	noise.emit_noise(guard.position + Vector3.UP, 1.0, guard)
	assert(worker.awareness.last_known_position == creature.position, "Friendly gunfire replaced the monster's position")
	worker.state_machine.physics_update(0.6)
	assert(worker.velocity.dot(away) > 0.0, "Gunfire made the civilian reverse toward the monster")
	worker.health.apply_damage(1000.0, creature)
	assert(not worker.alarm.indicator.visible and not worker.alarm.voice.playing, "Dead civilian kept an active alarm")
	print("ALIEN_DOOM_HUMAN_FLEE_ALARM_OK flee_away=true gunfire_memory=true icon=true audible_alert=true hearing_range=true")
	world.queue_free()
	await process_frame
	NavigationServer3D.free_rid(empty_map)
	quit(0)

func _spawn(world: Node3D, role: String, position: Vector3) -> HumanController:
	var human := (load("res://gameplay/humans/human.tscn") as PackedScene).instantiate() as HumanController
	human.role = role
	human.position = position
	world.add_child(human)
	human.set_physics_process(false)
	return human
