extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var creature := (load("res://gameplay/player/creature.tscn") as PackedScene).instantiate() as CreatureController
	world.add_child(creature)
	creature.set_physics_process(false)
	var worker := _spawn(world, "Worker", Vector3.ZERO)
	var guard := _spawn(world, "Guard", Vector3(40, 0, 0))
	await physics_frame
	for human in [worker, guard]:
		# Exercise the actual perception signal -> stress -> HFSM connection.
		creature.global_position = human.perception.global_position + Vector3(0, 0, -3)
		await physics_frame
		assert(human.perception.evaluate_target(creature, 1.0), "Direct vision did not detect the creature")
		assert(human.state_machine.current.name == "Alert", "Vision did not activate Alert")
		assert(human.state_machine.current.current_substate.name == ("Combat" if human.is_guard() else "Flee"), "Role selected the wrong threat response")
		human.stress.cap_stress(0.0)
		creature.global_position = human.perception.global_position + Vector3(4, 0, -1)
		await physics_frame
		assert(human.perception.evaluate_target(creature, 1.0), "Peripheral vision did not detect the creature")
		assert(human.state_machine.current.name == "Cautious", "Peripheral vision did not activate investigation")
		human.stress.cap_stress(0.0)
		creature.global_position = human.perception.global_position + Vector3(0, 0, 0.6)
		await physics_frame
		assert(human.perception.evaluate_target(creature, 1.0), "Close contact behind the human was not detected")
		assert(human.stress.state == StressComponent.State.ALERT, "Close contact did not raise stress")
		human.stress.cap_stress(0.0)
		var noise_position: Vector3 = human.perception.global_position + Vector3(0, 0, 3)
		(root.get_node("NOISE") as NoiseBus).emit_noise(noise_position, 1.0, creature)
		assert(human.state_machine.current.name == "Cautious", "Hearing is not wired into the HFSM")
		assert(human.awareness.last_known_position.is_equal_approx(noise_position), "Heard position was not remembered")
		human.stress.tick(14.0)
		assert(human.stress.value > 0.0, "Stress decayed before the grace period")
		human.stress.tick(61.0)
		assert(human.state_machine.current.name == "Calm", "Stress recovery did not return to Calm")

	var cone := guard.get_node("PerceptionComponent/GuardViewCone") as GuardViewCone
	assert(cone.visible and cone.mesh != null, "Guard direction cone is missing")
	assert(not worker.get_node("PerceptionComponent/GuardViewCone").visible, "Civilian has a guard cone")
	var worker_mesh := worker.get_node("HumanPresentationComponent").body_meshes[0] as MeshInstance3D
	var guard_mesh := guard.get_node("HumanPresentationComponent").body_meshes[0] as MeshInstance3D
	var worker_material := worker_mesh.get_surface_override_material(0) as BaseMaterial3D
	var guard_material := guard_mesh.get_surface_override_material(0) as BaseMaterial3D
	assert(worker_material != guard_material and worker_material.albedo_color != guard_material.albedo_color, "Role colors are missing or shared")

	# A real wall must block sight and the cone, but only attenuate hearing.
	var wall := StaticBody3D.new()
	wall.position = guard.position + Vector3(0, 2, -2)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(10, 8, 0.2)
	collision.shape = shape
	wall.add_child(collision)
	world.add_child(wall)
	creature.global_position = guard.perception.global_position + Vector3(0, 0, -4)
	await physics_frame
	assert(not guard.perception.evaluate_target(creature, 1.0), "Vision passed through a wall")
	cone.rebuild_mesh()
	var vertices: PackedVector3Array = cone.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for vertex in vertices:
		assert(vertex.z > -1.91, "Guard cone passed through the wall ahead")
	guard.stress.cap_stress(0.0)
	(root.get_node("NOISE") as NoiseBus).emit_noise(creature.global_position, 1.0, creature)
	assert(guard.stress.value > 0.0 and guard.stress.value < 15.0, "Wall did not attenuate hearing")

	# Warning must carry a destination before it triggers the recipient's behavior.
	worker.position = guard.position + Vector3(3, 0, 0)
	worker.stress.cap_stress(0.0)
	guard.awareness.remember_stimulus(creature.global_position, false)
	guard.stress.add_stress(100.0)
	guard._share_stress()
	assert(worker.stress.state == StressComponent.State.ALERT, "Nearby civilian did not receive alarm")
	assert(worker.awareness.last_known_position == creature.global_position, "Alarm did not transmit threat position")
	assert(worker.state_machine.current.current_substate.name == "Flee", "Shared alarm did not activate civilian flight")
	guard._on_stimulus(creature.global_position, 10.0, true)
	assert(guard.stress.state == StressComponent.State.ALERT, "Corpse incorrectly lowered existing alert")
	worker.role = "Guard"
	assert(worker.state_machine.current.current_substate.name == "Combat", "Changing role after spawn did not update behavior")
	assert(worker.get_node("PerceptionComponent/GuardViewCone").visible, "Changing role did not enable the cone")
	worker.role = "Engineer"
	assert(worker.role == "Worker" and worker.state_machine.current.current_substate.name == "Flee", "Legacy engineer should remain a civilian")
	guard.stress.cap_stress(0.0)
	guard.health.apply_damage(1.0, creature)
	assert(guard.stress.state == StressComponent.State.ALERT, "Damage did not alert the victim")
	guard.health.apply_damage(1000.0, creature)
	assert(not cone.visible and not cone.is_physics_processing(), "Dead guard still displays a cone")
	print("ALIEN_DOOM_HUMAN_PERCEPTION_WIRING_OK roles=2 sensors=4 wall_occlusion=true alarm_memory=true")
	world.queue_free()
	await process_frame
	quit(0)

func _spawn(world: Node3D, role: String, position: Vector3) -> HumanController:
	var human := (load("res://gameplay/humans/human.tscn") as PackedScene).instantiate() as HumanController
	human.role = role
	human.position = position
	world.add_child(human)
	human.set_physics_process(false)
	return human
