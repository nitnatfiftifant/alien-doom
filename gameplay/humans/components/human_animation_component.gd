class_name HumanAnimationComponent
extends Node

@export var actor: HumanController
@export var visual_root: Node3D
@export var combat: RangedCombatComponent
@export var movement_threshold := 0.15
@export_group("Skinned mesh visibility")
@export var extra_cull_margin := 5.0
@export var ignore_occlusion_culling := true

var animation_player: AnimationPlayer
var current_animation := &""
var death_started := false
var action_lock := 0.0
var fear_modifier: SkeletonModifier3D

func _ready() -> void:
	_configure_mesh_culling()
	animation_player = visual_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player == null:
		push_warning("Human animation model has no AnimationPlayer")
		return
	_set_loop(&"Idle", true)
	_set_loop(&"Walk", true)
	_set_loop(&"Jog_Fwd", true)
	_set_loop(&"Sprint", true)
	_set_loop(&"Crouch_Idle", true)
	_set_loop(&"Crouch_Fwd", true)
	var skeleton := visual_root.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton != null:
		fear_modifier = preload("res://gameplay/humans/components/human_fear_modifier.gd").new()
		fear_modifier.name = "HumanFearModifier"
		fear_modifier.actor = actor
		skeleton.add_child(fear_modifier)
	if combat != null:
		combat.shot_fired.connect(_on_shot_fired)
	_play(&"Idle")

func _configure_mesh_culling() -> void:
	for descendant in visual_root.find_children("*", "GeometryInstance3D", true, false):
		var geometry := descendant as GeometryInstance3D
		geometry.extra_cull_margin = extra_cull_margin
		geometry.ignore_occlusion_culling = ignore_occlusion_culling

func _process(delta: float) -> void:
	if animation_player == null:
		return
	if actor.is_in_group("corpses"):
		if not death_started:
			death_started = true
			_play(&"Death01")
		return
	action_lock = maxf(0.0, action_lock - delta)
	if action_lock > 0.0:
		return
	var horizontal_speed := Vector2(actor.velocity.x, actor.velocity.z).length()
	if actor.role == "Worker" and actor.civilian_crouching:
		_play(&"Crouch_Fwd" if horizontal_speed > movement_threshold else &"Crouch_Idle", horizontal_speed > movement_threshold)
		return
	if horizontal_speed <= movement_threshold:
		_play(&"Pistol_Idle" if actor.role == "Guard" else &"Idle")
	elif actor.stress.state == StressComponent.State.ALERT:
		_play(&"Sprint" if actor.role == "Worker" else &"Jog_Fwd")
	else:
		_play(&"Walk")

func _on_shot_fired() -> void:
	if actor.role != "Guard":
		return
	action_lock = 0.35
	current_animation = &""
	_play(&"Pistol_Shoot")

func _play(animation_name: StringName, backwards := false) -> void:
	if current_animation == animation_name or not animation_player.has_animation(animation_name):
		return
	current_animation = animation_name
	animation_player.play(animation_name, 0.15, -1.0 if backwards else 1.0, backwards)

func _set_loop(animation_name: StringName, enabled: bool) -> void:
	if not animation_player.has_animation(animation_name):
		return
	var animation := animation_player.get_animation(animation_name)
	animation.loop_mode = Animation.LOOP_LINEAR if enabled else Animation.LOOP_NONE
