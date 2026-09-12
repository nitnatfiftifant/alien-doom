class_name RagdollPusherComponent
extends Node

@export var actor: CharacterBody3D
@export var radius := 1.1
@export var push_force := 45.0

func physics_step() -> void:
	var planar_velocity := actor.velocity.slide(actor.up_direction)
	if planar_velocity.length_squared() < 0.25:
		return
	for candidate in actor.get_tree().get_nodes_in_group("corpse_ragdoll_parts"):
		var part := candidate as PhysicalBone3D
		if part == null:
			continue
		var offset := part.global_position - actor.global_position
		var distance := offset.length()
		if distance >= radius or distance <= 0.001:
			continue
		var strength := 1.0 - distance / radius
		part.apply_central_impulse(planar_velocity.normalized() * push_force * strength / 60.0)
