extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var creature := (load("res://gameplay/player/creature.tscn") as PackedScene).instantiate() as CreatureController
	# Keep the isolated target level with the guard's eye; floor/stance coverage
	# belongs to the map integration test, while this test isolates HFSM routing.
	creature.position = Vector3(0.0, 1.65, -3.0)
	root.add_child(creature)
	creature.set_physics_process(false)

	var guard := _spawn_human(root, "Guard", Vector3.ZERO)
	guard.set_physics_process(false)
	await physics_frame
	guard.awareness.remember_stimulus(creature.global_position, false)
	guard.awareness.track_creature(creature, true)
	guard.stress.add_stress(80.0)
	assert(guard.state_machine.current.name == "Alert", "Guard did not enter Alert container")
	assert(guard.state_machine.current.current_substate.name == "Combat", "Alert guard did not enter Combat substate")
	var health_before := creature.health.current_health
	guard.state_machine.physics_update(1.0)
	assert(creature.health.current_health < health_before, "Combat substate did not execute ranged combat")

	var worker := _spawn_human(root, "Worker", Vector3(4.0, 0.0, 0.0))
	worker.set_physics_process(false)
	worker.awareness.remember_stimulus(Vector3(5.0, 0.0, 0.0), false)
	worker.stress.add_stress(80.0)
	assert(worker.state_machine.current.name == "Alert", "Worker did not enter Alert container")
	assert(worker.state_machine.current.current_substate.name == "Flee", "Alert worker did not enter Flee substate")
	assert(worker.navigation.target_position.x < worker.global_position.x, "Flee target was not placed away from threat")

	var witness := _spawn_human(root, "Guard", Vector3(8.0, 0.0, 0.0))
	witness.set_physics_process(false)
	witness._on_stimulus(Vector3.ZERO, 100.0, true)
	assert(witness.stress.state == StressComponent.State.POST_ALERT, "Corpse stimulus exceeded PostAlert cap")
	assert(witness.state_machine.current.current_substate.name == "Search", "PostAlert guard did not enter Search substate")

	var configured := _spawn_human(root, "Worker", Vector3(12.0, 0.0, 0.0))
	configured.set_physics_process(false)
	configured._func_godot_apply_properties({
		"ai_move_speed": 4.75,
		"direct_view_distance": 21.0,
		"hearing_distance": 24.0,
		"search_radius": 6.5,
		"flee_distance": 14.0,
	})
	assert(is_equal_approx(configured.ai_config.move_speed, 4.75), "TrenchBroom movement override was not applied")
	assert(is_equal_approx(configured.perception.direct_view_distance, 21.0), "TrenchBroom vision override was not applied")
	assert(is_equal_approx(configured.perception.hearing_distance, 24.0), "TrenchBroom hearing override was not applied")
	assert(is_equal_approx(configured.ai_config.search_radius, 6.5) and is_equal_approx(configured.ai_config.flee_distance, 14.0), "TrenchBroom behavior overrides were not applied")
	assert(configured.ai_config != guard.ai_config, "Per-entity AI overrides modified the shared default resource")

	print("ALIEN_DOOM_HUMAN_HFSM_OK guard=Combat worker=Flee corpse=Search")
	root.queue_free()
	await process_frame
	quit(0)

func _spawn_human(parent: Node3D, role: String, position: Vector3) -> HumanController:
	var human := (load("res://gameplay/humans/human.tscn") as PackedScene).instantiate() as HumanController
	human.role = role
	human.position = position
	parent.add_child(human)
	return human
