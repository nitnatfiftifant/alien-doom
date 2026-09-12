class_name HumanRagdollComponent
extends Node

const CORPSE_LAYER := 8
@export var visual_root: Node3D
var skeleton: Skeleton3D
var simulator: PhysicalBoneSimulator3D
var bodies: Array[PhysicalBone3D] = []

const PARTS := {
	"pelvis": [Vector3(0.24, 0.20, 0.18), 12.0],
	"spine_02": [Vector3(0.30, 0.38, 0.18), 18.0],
	"Head": [Vector3(0.18, 0.22, 0.18), 5.0],
	"upperarm_l": [Vector3(0.11, 0.30, 0.11), 3.0], "lowerarm_l": [Vector3(0.09, 0.29, 0.09), 2.0],
	"upperarm_r": [Vector3(0.11, 0.30, 0.11), 3.0], "lowerarm_r": [Vector3(0.09, 0.29, 0.09), 2.0],
	"thigh_l": [Vector3(0.14, 0.43, 0.14), 7.0], "calf_l": [Vector3(0.11, 0.43, 0.11), 4.0],
	"thigh_r": [Vector3(0.14, 0.43, 0.14), 7.0], "calf_r": [Vector3(0.11, 0.43, 0.11), 4.0],
}

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
	for bone_name: String in PARTS:
		_create_physical_bone(bone_name, PARTS[bone_name][0], PARTS[bone_name][1])
	if simulator.has_method("physical_bones_start_simulation"):
		simulator.call("physical_bones_start_simulation")
	elif skeleton.has_method("physical_bones_start_simulation"):
		skeleton.call("physical_bones_start_simulation")
	for body in bodies: body.linear_velocity = impact_velocity

func _create_physical_bone(bone_name: String, size: Vector3, mass_value: float) -> void:
	if skeleton.find_bone(bone_name) < 0: return
	var body := PhysicalBone3D.new()
	body.name = "Ragdoll_" + bone_name
	body.bone_name = bone_name
	body.mass = mass_value
	body.linear_damp = 1.8
	body.angular_damp = 4.5
	body.collision_layer = CORPSE_LAYER
	body.collision_mask = 1
	body.add_to_group("corpse_ragdoll_parts")
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = minf(size.x, size.z)
	shape.height = maxf(size.y, shape.radius * 2.0)
	collision.shape = shape
	body.add_child(collision)
	simulator.add_child(body)
	_configure_joint_limits(body, bone_name)
	bodies.append(body)

func get_bodies() -> Array[PhysicalBone3D]: return bodies

func _configure_joint_limits(body: PhysicalBone3D, bone_name: String) -> void:
	if bone_name.begins_with("lowerarm_"):
		body.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE
		body.set("joint_constraints/angular_limit_enabled", true)
		body.set("joint_constraints/angular_limit_lower", deg_to_rad(-5.0))
		body.set("joint_constraints/angular_limit_upper", deg_to_rad(135.0))
	elif bone_name.begins_with("calf_"):
		body.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE
		body.set("joint_constraints/angular_limit_enabled", true)
		body.set("joint_constraints/angular_limit_lower", deg_to_rad(-130.0))
		body.set("joint_constraints/angular_limit_upper", deg_to_rad(5.0))
	else:
		body.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
		var swing := 35.0
		var twist := 20.0
		if bone_name.begins_with("upperarm_"): swing = 75.0; twist = 45.0
		if bone_name.begins_with("thigh_"): swing = 50.0; twist = 25.0
		if bone_name == "Head": swing = 30.0; twist = 25.0
		body.set("joint_constraints/swing_span", deg_to_rad(swing))
		body.set("joint_constraints/twist_span", deg_to_rad(twist))
		body.set("joint_constraints/softness", 0.65)
		body.set("joint_constraints/relaxation", 0.75)
