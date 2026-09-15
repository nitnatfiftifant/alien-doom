class_name HumanWeaponComponent
extends Node

@export var actor: HumanController
@export var visual_root: Node3D
@export var pistol_scene: PackedScene
@export var pistol_scale := 0.1
@export var pistol_position := Vector3(0.02, -0.02, 0.0)
@export var muzzle_local_position := Vector3(-3.51, 1.9, 0.0)
@export_group("Visibility")
@export_range(0.0, 100.0, 0.5, "or_greater") var extra_cull_margin := 5.0
@export var ignore_occlusion_culling := true

var weapon_instance: Node3D
var muzzle: Marker3D
var muzzle_flash: MeshInstance3D
var flash_timer := 0.0

func _ready() -> void:
	actor.get_node("RangedCombatComponent").shot_fired.connect(_on_shot_fired)
	actor.get_node("HealthComponent").died.connect(_on_died)
	refresh_role()

func refresh_role() -> void:
	if actor.is_guard() and weapon_instance == null and not actor.is_in_group("corpses"):
		_attach_guard_weapon()
	elif not actor.is_guard() and weapon_instance != null:
		weapon_instance.get_parent().queue_free()
		weapon_instance = null
		muzzle = null
		muzzle_flash = null

func _process(delta: float) -> void:
	flash_timer = maxf(0.0, flash_timer - delta)
	if muzzle_flash != null:
		muzzle_flash.visible = flash_timer > 0.0 and not actor.is_in_group("corpses")

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
	# Asset barrel = -X, up = +Y; UAL hand forward = +Y, up = +Z.
	weapon_instance.basis = Basis(Vector3.DOWN, Vector3.BACK, Vector3.LEFT).scaled(Vector3.ONE * pistol_scale)
	for descendant in weapon_instance.find_children("*", "GeometryInstance3D", true, false):
		var geometry := descendant as GeometryInstance3D
		geometry.extra_cull_margin = extra_cull_margin
		geometry.ignore_occlusion_culling = ignore_occlusion_culling
	muzzle = Marker3D.new()
	muzzle.name = "Muzzle"
	weapon_instance.add_child(muzzle)
	muzzle.position = muzzle_local_position
	muzzle.basis = Basis.looking_at(Vector3.LEFT, Vector3.UP)
	muzzle_flash = MeshInstance3D.new()
	muzzle_flash.name = "MuzzleFlash"
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.6
	flash_mesh.height = 1.2
	muzzle_flash.mesh = flash_mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.8, 0.3)
	muzzle_flash.material_override = material
	muzzle_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	muzzle_flash.extra_cull_margin = extra_cull_margin
	muzzle_flash.ignore_occlusion_culling = ignore_occlusion_culling
	muzzle_flash.visible = false
	muzzle.add_child(muzzle_flash)

func _on_shot_fired() -> void:
	flash_timer = 0.055
	if muzzle_flash != null:
		muzzle_flash.visible = true

func _on_died(_instigator: Node) -> void:
	flash_timer = 0.0
	if muzzle_flash != null:
		muzzle_flash.visible = false
