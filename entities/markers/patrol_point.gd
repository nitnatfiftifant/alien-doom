@tool
class_name HumanPatrolPoint
extends Marker3D

@export var targetname := ""
@export var patrol_id := ""
@export var point_index := 0
@export_range(0.0, 10.0, 0.1) var wait_seconds := 0.8

func _func_godot_apply_properties(properties: Dictionary) -> void:
	targetname = str(properties.get("targetname", targetname))
	patrol_id = str(properties.get("patrol_id", patrol_id))
	point_index = int(properties.get("point_index", point_index))
	wait_seconds = maxf(float(properties.get("wait_seconds", wait_seconds)), 0.0)

func _ready() -> void:
	add_to_group("human_patrol_points")
