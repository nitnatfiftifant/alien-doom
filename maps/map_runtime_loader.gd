extends Node

@export var map: FuncGodotMap

func _ready() -> void:
	assert(map != null, "MapRuntimeLoader requires a FuncGodotMap dependency")
	if Engine.is_editor_hint():
		return
	map.build()
