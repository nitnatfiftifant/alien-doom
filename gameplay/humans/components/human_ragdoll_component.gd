class_name HumanRagdollComponent
extends Node

const CORPSE_LAYER := 8
@export var visual_root: Node3D
@export_group("Physics")
@export_flags_3d_physics var corpse_layer := CORPSE_LAYER
@export_flags_3d_physics var collision_mask := 13
@export_range(0.0, 10.0) var linear_damping := 3.0
@export_range(0.0, 20.0) var angular_damping := 8.0
@export var continuous_collision_detection := true
@export var maximum_linear_speed := 10.0
@export var maximum_angular_speed := 14.0
@export_group("Web optimization")
@export var automatic_deactivation := true
@export var sleep_after_seconds := 1.0
@export var freeze_after_seconds := 4.0
@export var sleep_linear_threshold := 0.12
@export var sleep_angular_threshold := 0.18
@export var disable_ccd_while_settled := true
@export_group("Mass")
@export var pelvis_mass := 12.0
@export var lower_spine_mass := 6.0
@export var torso_mass := 18.0
@export var upper_spine_mass := 7.0
@export var neck_mass := 1.5
@export var head_mass := 5.0
@export var clavicle_mass := 1.5
@export var upper_arm_mass := 3.0
@export var lower_arm_mass := 2.0
@export var hand_mass := 0.8
@export var thigh_mass := 7.0
@export var calf_mass := 4.0
@export var foot_mass := 1.2
@export_group("Collision shapes")
@export var pelvis_size := Vector3(0.24, 0.20, 0.18)
@export var lower_spine_size := Vector3(0.22, 0.18, 0.16)
@export var torso_size := Vector3(0.30, 0.38, 0.18)
@export var upper_spine_size := Vector3(0.30, 0.20, 0.18)
@export var neck_size := Vector3(0.09, 0.12, 0.09)
@export var head_size := Vector3(0.18, 0.22, 0.18)
@export var clavicle_size := Vector3(0.10, 0.18, 0.10)
@export var upper_arm_size := Vector3(0.11, 0.30, 0.11)
@export var lower_arm_size := Vector3(0.09, 0.29, 0.09)
@export var hand_size := Vector3(0.09, 0.14, 0.09)
@export var thigh_size := Vector3(0.14, 0.43, 0.14)
@export var calf_size := Vector3(0.11, 0.43, 0.11)
@export var foot_size := Vector3(0.11, 0.22, 0.11)
@export_range(0.0, 1.0) var shape_length_offset_ratio := 0.5
@export_group("Skeleton mapping")
@export var pelvis_bone := &"pelvis"
@export var lower_spine_bone := &"spine_01"
@export var torso_bone := &"spine_02"
@export var upper_spine_bone := &"spine_03"
@export var neck_bone := &"neck_01"
@export var head_bone := &"Head"
@export var clavicle_left_bone := &"clavicle_l"
@export var clavicle_right_bone := &"clavicle_r"
@export var upper_arm_left_bone := &"upperarm_l"
@export var lower_arm_left_bone := &"lowerarm_l"
@export var hand_left_bone := &"hand_l"
@export var upper_arm_right_bone := &"upperarm_r"
@export var lower_arm_right_bone := &"lowerarm_r"
@export var hand_right_bone := &"hand_r"
@export var thigh_left_bone := &"thigh_l"
@export var calf_left_bone := &"calf_l"
@export var foot_left_bone := &"foot_l"
@export var thigh_right_bone := &"thigh_r"
@export var calf_right_bone := &"calf_r"
@export var foot_right_bone := &"foot_r"
@export_group("Joint limits (degrees)")
@export var elbow_lower := -5.0
@export var elbow_upper := 135.0
@export var knee_lower := -130.0
@export var knee_upper := 5.0
@export var default_swing := 35.0
@export var default_twist := 20.0
@export var shoulder_swing := 75.0
@export var shoulder_twist := 45.0
@export var hip_swing := 50.0
@export var hip_twist := 25.0
@export var neck_swing := 30.0
@export var neck_twist := 25.0
@export var spine_swing := 18.0
@export var spine_twist := 12.0
@export var clavicle_swing := 25.0
@export var clavicle_twist := 15.0
@export var wrist_swing := 35.0
@export var wrist_twist := 30.0
@export var ankle_swing := 25.0
@export var ankle_twist := 15.0
@export_range(0.0, 1.0) var joint_softness := 0.65
@export_range(0.0, 1.0) var joint_relaxation := 0.75
var skeleton: Skeleton3D
var simulator: PhysicalBoneSimulator3D
var bodies: Array[PhysicalBone3D] = []
var settled_time := 0.0
var is_frozen := false
var is_forced_sleeping := false

func activate(impact_velocity := Vector3.ZERO) -> void:
	if simulator != null: return
	skeleton = visual_root.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		push_error("Human ragdoll requires the model Skeleton3D")
		return
	var animation_player := visual_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player != null: animation_player.stop()
	simulator = PhysicalBoneSimulator3D.new()
	simulator.name = "PhysicalBoneSimulator3D"
	skeleton.add_child(simulator)
	for bone_name: String in _parts():
		_create_physical_bone(bone_name, _parts()[bone_name][0], _parts()[bone_name][1])
	_exclude_self_collisions()
	if simulator.has_method("physical_bones_start_simulation"):
		simulator.call("physical_bones_start_simulation")
	elif skeleton.has_method("physical_bones_start_simulation"):
		skeleton.call("physical_bones_start_simulation")
	for body in bodies: body.linear_velocity = impact_velocity
	set_physics_process(true)

func _ready() -> void:
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	var all_settled := true
	for body in bodies:
		if body == null or not is_instance_valid(body): continue
		body.linear_velocity = body.linear_velocity.limit_length(maximum_linear_speed)
		body.angular_velocity = body.angular_velocity.limit_length(maximum_angular_speed)
		if body.linear_velocity.length() > sleep_linear_threshold or body.angular_velocity.length() > sleep_angular_threshold:
			all_settled = false
	if not automatic_deactivation: return
	settled_time = settled_time + delta if all_settled else 0.0
	if all_settled and not is_forced_sleeping and settled_time >= sleep_after_seconds:
		_set_sleeping(true)
	if all_settled and settled_time >= freeze_after_seconds:
		_set_frozen(true)

func wake() -> void:
	if bodies.is_empty(): return
	if is_frozen:
		for body in bodies:
			PhysicsServer3D.body_set_mode(body.get_rid(), PhysicsServer3D.BODY_MODE_RIGID)
	is_frozen = false
	settled_time = 0.0
	_set_sleeping(false)
	set_physics_process(true)

func _set_sleeping(value: bool) -> void:
	is_forced_sleeping = value
	for body in bodies:
		PhysicsServer3D.body_set_state(body.get_rid(), PhysicsServer3D.BODY_STATE_SLEEPING, value)
		if disable_ccd_while_settled:
			PhysicsServer3D.body_set_enable_continuous_collision_detection(body.get_rid(), continuous_collision_detection and not value)

func _set_frozen(value: bool) -> void:
	if is_frozen == value: return
	is_frozen = value
	if value:
		for body in bodies:
			PhysicsServer3D.body_set_mode(body.get_rid(), PhysicsServer3D.BODY_MODE_STATIC)
		set_physics_process(false)

func _create_physical_bone(bone_name: String, size: Vector3, mass_value: float) -> void:
	if skeleton.find_bone(bone_name) < 0: return
	var body := PhysicalBone3D.new()
	body.name = "Ragdoll_" + bone_name
	body.bone_name = bone_name
	body.mass = mass_value
	body.linear_damp = linear_damping
	body.angular_damp = angular_damping
	body.collision_layer = corpse_layer
	body.collision_mask = collision_mask
	body.add_to_group("corpse_ragdoll_parts")
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = minf(size.x, size.z)
	shape.height = maxf(size.y, shape.radius * 2.0)
	collision.shape = shape
	collision.position.y = shape.height * shape_length_offset_ratio
	body.add_child(collision)
	simulator.add_child(body)
	if continuous_collision_detection:
		PhysicsServer3D.body_set_enable_continuous_collision_detection(body.get_rid(), true)
	_configure_joint_limits(body, bone_name)
	bodies.append(body)

func get_bodies() -> Array[PhysicalBone3D]: return bodies

func _exclude_self_collisions() -> void:
	for first_index in bodies.size():
		for second_index in range(first_index + 1, bodies.size()):
			bodies[first_index].add_collision_exception_with(bodies[second_index])
			bodies[second_index].add_collision_exception_with(bodies[first_index])

func _configure_joint_limits(body: PhysicalBone3D, bone_name: String) -> void:
	if bone_name == str(lower_arm_left_bone) or bone_name == str(lower_arm_right_bone):
		body.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE
		body.set("joint_constraints/angular_limit_enabled", true)
		body.set("joint_constraints/angular_limit_lower", deg_to_rad(elbow_lower))
		body.set("joint_constraints/angular_limit_upper", deg_to_rad(elbow_upper))
	elif bone_name == str(calf_left_bone) or bone_name == str(calf_right_bone):
		body.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE
		body.set("joint_constraints/angular_limit_enabled", true)
		body.set("joint_constraints/angular_limit_lower", deg_to_rad(knee_lower))
		body.set("joint_constraints/angular_limit_upper", deg_to_rad(knee_upper))
	else:
		body.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
		var swing := default_swing
		var twist := default_twist
		if bone_name == str(upper_arm_left_bone) or bone_name == str(upper_arm_right_bone): swing = shoulder_swing; twist = shoulder_twist
		if bone_name == str(thigh_left_bone) or bone_name == str(thigh_right_bone): swing = hip_swing; twist = hip_twist
		if bone_name == str(head_bone): swing = neck_swing; twist = neck_twist
		if bone_name == str(lower_spine_bone) or bone_name == str(torso_bone) or bone_name == str(upper_spine_bone): swing = spine_swing; twist = spine_twist
		if bone_name == str(clavicle_left_bone) or bone_name == str(clavicle_right_bone): swing = clavicle_swing; twist = clavicle_twist
		if bone_name == str(hand_left_bone) or bone_name == str(hand_right_bone): swing = wrist_swing; twist = wrist_twist
		if bone_name == str(foot_left_bone) or bone_name == str(foot_right_bone): swing = ankle_swing; twist = ankle_twist
		body.set("joint_constraints/swing_span", deg_to_rad(swing))
		body.set("joint_constraints/twist_span", deg_to_rad(twist))
		body.set("joint_constraints/softness", joint_softness)
		body.set("joint_constraints/relaxation", joint_relaxation)

func _parts() -> Dictionary:
	return {
		str(pelvis_bone): [pelvis_size, pelvis_mass],
		str(lower_spine_bone): [lower_spine_size, lower_spine_mass],
		str(torso_bone): [torso_size, torso_mass],
		str(upper_spine_bone): [upper_spine_size, upper_spine_mass],
		str(neck_bone): [neck_size, neck_mass], str(head_bone): [head_size, head_mass],
		str(clavicle_left_bone): [clavicle_size, clavicle_mass],
		str(upper_arm_left_bone): [upper_arm_size, upper_arm_mass], str(lower_arm_left_bone): [lower_arm_size, lower_arm_mass],
		str(hand_left_bone): [hand_size, hand_mass],
		str(clavicle_right_bone): [clavicle_size, clavicle_mass],
		str(upper_arm_right_bone): [upper_arm_size, upper_arm_mass], str(lower_arm_right_bone): [lower_arm_size, lower_arm_mass],
		str(hand_right_bone): [hand_size, hand_mass],
		str(thigh_left_bone): [thigh_size, thigh_mass], str(calf_left_bone): [calf_size, calf_mass], str(foot_left_bone): [foot_size, foot_mass],
		str(thigh_right_bone): [thigh_size, thigh_mass], str(calf_right_bone): [calf_size, calf_mass], str(foot_right_bone): [foot_size, foot_mass],
	}
