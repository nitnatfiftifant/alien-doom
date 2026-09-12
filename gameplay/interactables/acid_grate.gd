@tool
class_name AcidGrate
extends StaticBody3D

signal dissolved
@export var acid_resistance := 1
var acid_hits := 0

func dissolve_by_acid() -> void:
	acid_hits += 1
	if acid_hits < acid_resistance: return
	dissolved.emit()
	if Engine.is_editor_hint(): return
	queue_free()

