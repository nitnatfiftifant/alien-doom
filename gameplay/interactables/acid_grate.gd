@tool
class_name AcidGrate
extends StaticBody3D

signal dissolved
@export var acid_resistance := 1
var acid_hits := 0

func _func_godot_apply_properties(properties: Dictionary) -> void:
	acid_resistance = maxi(1, int(properties.get("acid_resistance", acid_resistance)))

func dissolve_by_acid() -> void:
	acid_hits += 1
	if acid_hits < acid_resistance: return
	dissolved.emit()
	if Engine.is_editor_hint(): return
	queue_free()
