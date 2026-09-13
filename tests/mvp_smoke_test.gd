extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var packed := load("res://maps/ventilation_blockout.tscn") as PackedScene
	assert(packed != null)
	var world := packed.instantiate()
	get_root().add_child(world)
	await process_frame
	await process_frame
	var creature := get_first_node_in_group("creature") as CreatureController
	var humans := get_nodes_in_group("humans")
	var nest := get_first_node_in_group("creature_nest") as CreatureNest
	assert(creature != null, "Creature was not spawned from info_alien_start")
	var sensor_panel := creature.get_node("CreatureHud/SensorDebugPanel") as SurfaceSensorDebugPanel
	assert(sensor_panel != null, "Surface sensor debug panel is missing from HUD")
	assert(sensor_panel.motor == creature.motor and sensor_panel.view_camera == creature.get_node("CameraPivot/Camera3D"), "Surface sensor debug dependencies are not wired")
	sensor_panel._collect_samples()
	assert(sensor_panel.get_samples().size() >= 10, "Sensor panel does not expose legs, motor probes and adhesion ray")
	var pause_menu := creature.get_node("PauseMenu")
	assert(pause_menu != null and pause_menu.slider.min_value == pause_menu.minimum_sensitivity, "Pause menu mouse sensitivity control is not configured")
	pause_menu.pause()
	assert(paused and pause_menu.overlay.visible, "Pause menu did not pause the scene tree")
	pause_menu.resume()
	assert(not paused and not pause_menu.overlay.visible, "Pause menu did not resume the scene tree")
	assert(creature.run_speed == 4.0 and creature.jump_impulse == 6.5 and creature.jump_forward_impulse == 0.0 and creature.gravity_strength == 16.0, "CreatureController movement scene values missing")
	creature.run_speed = 11.0
	assert(creature.motor.run_speed == 11.0, "Changing CreatureController exported run_speed did not sync to motor")
	creature.run_speed = 4.0
	assert(InputMap.has_action(&"jump") and InputMap.has_action(&"floor_detach"), "InputMap is missing jump or floor_detach actions")
	for action_name in [&"jump", &"floor_detach", &"move_forward", &"bite", &"acid", &"interact"]:
		var events := InputMap.action_get_events(action_name)
		assert(not events.is_empty(), "InputMap action %s has no assigned events" % action_name)
		for ev in events:
			assert(ev.device == -1, "InputEvent for %s has invalid device id %d (must be -1)" % [action_name, ev.device])
	assert(not humans.is_empty(), "At least one human must spawn from the current TrenchBroom markers")
	assert(nest != null, "Nest was not spawned from info_nest")
	var human := humans[0] as HumanController
	var guard: HumanController
	for candidate in humans:
		if (candidate as HumanController).role == "Guard":
			guard = candidate as HumanController
	assert(guard != null, "TrenchBroom guard role was not applied")
	var guard_weapon := guard.get_node("HumanWeaponComponent") as HumanWeaponComponent
	assert(guard_weapon.weapon_instance != null, "Guard pistol was not attached to hand_r")
	var guard_animator := guard.get_node("HumanAnimationComponent") as HumanAnimationComponent
	guard.combat.shot_fired.emit()
	assert(guard_animator.current_animation == &"Pistol_Shoot", "Guard shot did not trigger the pistol animation")
	assert(absf(absf(guard.get_node("VisualRoot").rotation.y) - PI) < 0.01, "Human visual orientation correction is missing")
	assert(human.state_machine.current != null)
	var animator := human.get_node("HumanAnimationComponent") as HumanAnimationComponent
	assert(animator.animation_player != null, "Human test model or its AnimationPlayer is missing")
	for geometry in human.get_node("VisualRoot/AnimatedModel").find_children("*", "GeometryInstance3D", true, false):
		assert((geometry as GeometryInstance3D).extra_cull_margin >= 5.0 and (geometry as GeometryInstance3D).ignore_occlusion_culling, "Human skinned mesh can disappear due to culling")
	assert(animator.animation_player.has_animation(&"Idle") and animator.animation_player.has_animation(&"Walk") and animator.animation_player.has_animation(&"Death01"), "Required human animation set is incomplete")
	human.stress.add_stress(80.0)
	assert(human.state_machine.current.state_id == StressComponent.State.ALERT, "FSM did not transition to Alert node")
	assert(human.state_machine.current.current_substate != null, "HFSM container did not activate a behavioral substate")
	human.global_basis = Basis.IDENTITY
	creature.global_position = human.global_position + Vector3.BACK
	var back_damage := creature.abilities.calculate_bite_damage(human, creature)
	creature.global_position = human.global_position + Vector3.FORWARD
	var front_damage := creature.abilities.calculate_bite_damage(human, creature)
	assert(back_damage > front_damage, "Bite from behind did not receive its damage multiplier")
	human.health.apply_damage(front_damage, creature)
	assert(human.health.current_health == 50.0, "A frontal bite must remove half of default human health")
	human.health.apply_damage(front_damage, creature)
	await physics_frame
	var corpse := get_first_node_in_group("corpses") as HumanController
	assert(corpse == human and human.ragdoll.bodies.size() >= 20, "Dead human did not activate a continuous full-body skinned-model ragdoll")
	assert(human.get_node("VisualRoot").visible, "Death replaced or hid the original skinned model")
	for ragdoll_body in human.ragdoll.bodies:
		assert((ragdoll_body.collision_mask & 13) == 13 and (ragdoll_body.collision_mask & 2) == 0, "Ragdoll collision mask must include world, humans and corpses but exclude creature")
	creature.global_basis = Basis(Vector3.RIGHT, PI * 0.5)
	creature.motor.surface_up = Vector3.FORWARD
	creature.camera_pivot.rotation.x = 1.0
	creature.health.apply_damage(200.0, human)
	assert(creature.health.current_health == creature.health.maximum_health, "Creature did not respawn with restored health")
	assert(creature.motor.surface_up.is_equal_approx(Vector3.UP), "Respawn did not reset the attached surface")
	assert(creature.global_basis.y.normalized().is_equal_approx(Vector3.UP), "Respawn did not reset body orientation")
	assert(is_zero_approx(creature.camera_pivot.rotation.x), "Respawn did not reset camera pitch")
	print("ALIEN_DOOM_MVP_SMOKE_OK fsm_nodes=%d" % human.state_machine.states.size())
	world.queue_free()
	await process_frame
	await process_frame
	quit(0)
