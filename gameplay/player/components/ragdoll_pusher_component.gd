class_name RagdollPusherComponent
extends Node

@export var actor: CharacterBody3D
@export var radius := 1.5
@export var push_force := 180.0
@export var minimum_push_speed := 0.5
@export var reference_physics_rate := 60.0
@export_group("Contact push")
@export var contact_impulse_scale := 2.2
@export var maximum_contact_impulse := 22.0

func physics_step() -> void:
	var planar_velocity := actor.velocity.slide(actor.up_direction)
	if planar_velocity.length_squared() < minimum_push_speed * minimum_push_speed:
		return
	var contacted: Array[PhysicalBone3D] = []
	for index in actor.get_slide_collision_count():
		var collision := actor.get_slide_collision(index)
		var part := collision.get_collider() as PhysicalBone3D
		if part == null or contacted.has(part): continue
		var impulse := (planar_velocity * contact_impulse_scale).limit_length(maximum_contact_impulse)
		_wake_ragdoll(part)
		part.apply_impulse(impulse, collision.get_position() - part.global_position)
		contacted.append(part)
	for candidate in actor.get_tree().get_nodes_in_group("corpse_ragdoll_parts"):
		var part := candidate as PhysicalBone3D
		if part == null or contacted.has(part):
			continue
		var offset := part.global_position - actor.global_position
		var distance := offset.length()
		if distance >= radius or distance <= 0.001:
			continue
		var strength := 1.0 - distance / radius
		_wake_ragdoll(part)
		part.apply_central_impulse(planar_velocity.normalized() * push_force * strength / reference_physics_rate)

func _wake_ragdoll(body: PhysicalBone3D) -> void:
	var current: Node = body
	while current != null:
		if current is HumanController:
			(current as HumanController).ragdoll.wake()
			return
		current = current.get_parent()
