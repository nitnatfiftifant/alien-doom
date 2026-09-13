class_name HumanWeaponComponent
extends Node

@export var actor: HumanController
@export var visual_root: Node3D
@export var pistol_scene: PackedScene
@export var pistol_scale := 0.1
@export var pistol_position := Vector3(0.02, -0.02, 0.0)
@export var pistol_rotation_degrees := Vector3(0.0, 90.0, 0.0)
@export_group("Visibility")
@export_range(0.0, 100.0, 0.5, "or_greater") var extra_cull_margin := 5.0
@export var ignore_occlusion_culling := true

var weapon_instance: Node3D

func _process(_delta: float) -> void:
	if actor.role == "Guard" and weapon_instance == null:
		_attach_guard_weapon()
	elif actor.role != "Guard" and weapon_instance != null:
		weapon_instance.get_parent().queue_free()
		weapon_instance = null

func _attach_guard_weapon() -> void:
	if pistol_scene == null:
		return
	var skeleton := visual_root.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null or skeleton.find_bone("hand_r") < 0:
		push_warning("Guard weapon requires the hand_r bone")
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = "RightHandWeaponAttachment"
	attachment.bone_name = "hand_r"
	skeleton.add_child(attachment)
	weapon_instance = pistol_scene.instantiate() as Node3D
	weapon_instance.name = "GuardPistol"
	attachment.add_child(weapon_instance)
	weapon_instance.position = pistol_position
	weapon_instance.rotation_degrees = pistol_rotation_degrees
	weapon_instance.scale = Vector3.ONE * pistol_scale
	for descendant in weapon_instance.find_children("*", "GeometryInstance3D", true, false):
		var geometry := descendant as GeometryInstance3D
		geometry.extra_cull_margin = extra_cull_margin
		geometry.ignore_occlusion_culling = ignore_occlusion_culling
