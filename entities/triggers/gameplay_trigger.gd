@tool
class_name AlienDoomGameplayTrigger
extends Area3D

@export var targetname: String = ""
@export var event_id: String = ""
@export var once: bool = true

func _init() -> void:
	monitoring = true
	monitorable = false

