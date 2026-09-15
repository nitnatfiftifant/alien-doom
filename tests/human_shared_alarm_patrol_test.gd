extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(40.0).timeout.connect(func():
		push_error("Shared alarm / actual map patrol test timed out")
		quit(1)
	)
	var world := Node3D.new()
	root.add_child(world)
	var guard := _spawn(world, "Guard", Vector3.ZERO)
	var worker := _spawn(world, "Worker", Vector3(7, 0, 0))
	var relay := _spawn(world, "Guard", Vector3(14, 0, 0))
	var outside := _spawn(world, "Worker", Vector3(23, 0, 0))
	guard.ai_config = guard.ai_config.duplicate(true)
	guard.ai_config.stress_share_radius = 6.0
	guard.awareness.remember_stimulus(Vector3(0, 0, -3), false)
	guard.stress.add_stress(100.0)
	assert(guard.alarm.indicator.visible and guard.alarm.indicator.text == "!", "Guard has no alarm icon")
	guard._share_stress()
	assert(worker.stress.state == StressComponent.State.CALM, "Shared alarm ignored sender radius")
	guard.ai_config.stress_share_radius = 8.0
	guard._share_stress()
	assert(worker.stress.value == guard.stress.value and worker.alarm.indicator.text == "!", "Worker shows suspicion after receiving guard alarm")
	assert(not worker.alarm.confirmed_sighting, "Receiving alarm should not fabricate a personal sighting")
	worker._share_stress()
	assert(relay.stress.value == worker.stress.value and relay.alarm.indicator.text == "!", "Civilian did not relay alarm to the next guard")
	assert(relay.awareness.last_known_position == guard.awareness.last_known_position, "Relay lost the threat position")
	relay._share_stress()
	assert(outside.stress.state == StressComponent.State.CALM and not outside.alarm.indicator.visible, "Alarm crossed a gap larger than sender radius")
	# Old relayed information must not reset everybody's recovery every frame.
	for frame in 1800:
		for human in [guard, worker, relay]:
			human.stress.tick(0.1)
			human._share_stress()
	for human in [guard, worker, relay]:
		assert(human.stress.state == StressComponent.State.CALM and not human.alarm.indicator.visible, "Group alarm never recovers without fresh stimuli")
	relay.stress.add_stress(20.0)
	assert(relay.alarm.indicator.text == "?" and relay.alarm.indicator.visible, "Guard does not show suspicion")
	relay.stress.add_stress(30.0)
	assert(relay.alarm.indicator.text == "!", "PostAlert guard still shows a question mark")
	world.queue_free()
	await process_frame
	await _test_actual_map_patrol()
	print("ALIEN_DOOM_SHARED_ALARM_PATROL_OK relay=true icons_both_roles=true radius=true recovery=true actual_map=A-B-A interrupt_resume=true")
	quit(0)

func _test_actual_map_patrol() -> void:
	var level := (load("res://maps/ventilation_blockout.tscn") as PackedScene).instantiate()
	root.add_child(level)
	var creature := get_first_node_in_group("creature") as CreatureController
	creature.set_physics_process(false)
	creature.position = Vector3(1000, 1000, 1000)
	var guard: HumanController
	for candidate in get_nodes_in_group("humans"):
		if candidate.targetname == "guard_01":
			guard = candidate
	assert(guard != null, "Patrol guard not found in actual level")
	var points: Array[HumanPatrolPoint] = []
	for point in get_nodes_in_group("human_patrol_points"):
		if point.patrol_id == guard.patrol_id: points.append(point)
	points.sort_custom(func(a, b): return a.point_index < b.point_index)
	assert(points.size() == 2, "Actual room must contain exactly two points for guard_01")
	var expected := [0, 1, 0]
	var visits := 0
	for frame in 1100:
		await physics_frame
		assert(guard.stress.state == StressComponent.State.CALM, "Patrol test was interrupted by an unexpected stimulus")
		if guard.global_position.distance_to(points[expected[visits]].global_position) < 0.7:
			print("PATROL_REACHED ", expected[visits], " position=", guard.global_position)
			visits += 1
			if visits == expected.size(): break
	assert(visits == 3, "Guard did not physically walk A -> B -> A in the authored room")
	guard._on_stimulus(guard.position + Vector3(0, 0, 2), 80.0, false)
	assert(guard.state_machine.current.name == "Alert", "Threat did not interrupt patrol")
	guard.stress.cap_stress(0.0)
	assert(guard.state_machine.current.current_substate.name == "Patrol", "Recovered guard did not resume patrol")
	var resume_position := guard.global_position
	for frame in 120: await physics_frame
	assert(guard.global_position.distance_to(resume_position) > 1.0, "Resumed patrol did not move")
	level.queue_free()
	await process_frame

func _spawn(world: Node3D, role: String, position: Vector3) -> HumanController:
	var human := (load("res://gameplay/humans/human.tscn") as PackedScene).instantiate() as HumanController
	human.role = role
	human.position = position
	world.add_child(human)
	human.set_physics_process(false)
	return human
