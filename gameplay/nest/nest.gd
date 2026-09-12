class_name CreatureNest
extends Area3D

signal corpse_delivered(total: int)
@export var heal_per_second := 30.0
var delivered_corpses := 0
@export var capacity := 4

func _func_godot_apply_properties(properties: Dictionary) -> void:
	capacity = int(properties.get("capacity", capacity))

func _ready() -> void:
	add_to_group("creature_nest")

func _physics_process(delta: float) -> void:
	for body in get_overlapping_bodies():
		if body is CreatureController:
			body.health.heal(heal_per_second * delta)
			if body.carry.carried:
				var corpse: Node3D = body.carry.consume_carried()
				corpse.queue_free()
				delivered_corpses += 1
				corpse_delivered.emit(delivered_corpses)
