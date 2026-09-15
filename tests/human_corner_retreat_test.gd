extends SceneTree

var world: Node3D
var worker: HumanController

func _init() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(25.0).timeout.connect(func():
		push_error("Corner retreat test timed out")
		quit(1)
	)
	world = Node3D.new()
	root.add_child(world)
	_box(Vector3(0, -0.2, 0), Vector3(30, 0.4, 30))
	worker = (load("res://gameplay/humans/human.tscn") as PackedScene).instantiate()
	world.add_child(worker)
	worker.set_physics_process(false)
	worker.awareness.remember_stimulus(Vector3(0, 0, -2), false)
	worker.stress.add_stress(80)
	var anim := worker.get_node("HumanAnimationComponent") as HumanAnimationComponent
	await physics_frame
	for frame in 40:
		# An approaching threat stays close as the worker retreats.
		worker.awareness.remember_stimulus(worker.position + Vector3(0, 0, -2), false)
		await _step()
	assert(worker.position.z > 0.6, "Close worker failed to retreat")
	assert((-worker.global_basis.z).dot(Vector3.FORWARD) > 0.95, "Worker turned his back while backpedaling")
	assert(anim.current_animation == &"Crouch_Fwd" and anim.animation_player.get_playing_speed() < 0, "Backward crouch animation missing")
	worker.position = Vector3.ZERO
	worker.velocity = Vector3.ZERO
	var wall_x := _box(Vector3(0.9, 1.5, 0), Vector3(0.2, 3, 8))
	var wall_z := _box(Vector3(0, 1.5, 0.9), Vector3(8, 3, 0.2))
	worker.awareness.remember_stimulus(Vector3(-2, 0, -2), false)
	for frame in 50: await _step()
	assert(worker.civilian_crouching and worker.velocity.slide(Vector3.UP).length() < 0.01, "Cornered worker kept running into walls")
	assert(anim.current_animation == &"Crouch_Idle", "Cornered worker did not crouch")
	assert(anim.fear_modifier != null and anim.fear_modifier.blend > 0.95, "Pleading animation did not blend in")
	var skeleton := anim.fear_modifier.get_skeleton()
	# Read the final pose while modifiers are applied (Godot restores it afterwards).
	var hands_raised := {"ok": false}
	skeleton.skeleton_updated.connect(func():
		var head := skeleton.get_bone_global_pose(skeleton.find_bone("Head")).origin
		var left := skeleton.get_bone_global_pose(skeleton.find_bone("hand_l")).origin
		var right := skeleton.get_bone_global_pose(skeleton.find_bone("hand_r")).origin
		hands_raised.ok = left.y > head.y - 0.3 and right.y > head.y - 0.3 and left.distance_to(right) < 0.3
	)
	var corner_position := worker.position
	for frame in 35: await _step()
	assert(hands_raised.ok, "Pleading hands must be raised together near the face")
	assert(worker.position.distance_to(corner_position) < 0.02, "Cornered worker jitters")
	if "--preview" in OS.get_cmdline_user_args():
		await _preview()
	wall_x.queue_free()
	wall_z.queue_free()
	worker.awareness.remember_stimulus(Vector3(-8, 0, -8), false)
	for frame in 45: await _step()
	assert(not worker.civilian_crouching and worker.position.distance_to(corner_position) > 1.0, "Worker did not resume fleeing when escape opened")
	assert(anim.current_animation == &"Sprint" and anim.animation_player.get_playing_speed() > 0, "Sprint remained reversed after crouch")
	worker.stress.cap_stress(0.0)
	assert(not worker.civilian_crouching, "Crouch survived leaving Flee")
	print("ALIEN_DOOM_HUMAN_CORNER_RETREAT_OK backpedal=true facing=true crouch=true corner_stable=true recovery=true")
	world.queue_free()
	await process_frame
	quit(0)

func _step() -> void:
	worker.state_machine.physics_update(1.0 / 60.0)
	worker.velocity.y = -0.5
	worker.move_and_slide()
	await physics_frame

func _box(position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = position
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	body.add_child(mesh)
	world.add_child(body)
	return body

func _preview() -> void:
	root.size = Vector2i(1000, 800)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(-4, 2.6, -4)
	camera.look_at(Vector3(0, 1, 0))
	camera.current = true
	var sun := DirectionalLight3D.new()
	world.add_child(sun)
	sun.rotation_degrees = Vector3(-45, -30, 0)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.5
	world.add_child(env)
	for frame in 15: await process_frame
	await RenderingServer.frame_post_draw
	var args := OS.get_cmdline_user_args()
	root.get_texture().get_image().save_png(args[args.find("--preview") + 1])
