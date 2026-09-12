@tool
class_name FuncOmniLight
extends OmniLight3D

func _func_godot_apply_properties(properties: Dictionary) -> void:
	var color_value = properties.get("_color", light_color)
	if color_value is Color:
		light_color = color_value
	elif color_value is String:
		var parts := (color_value as String).split(" ")
		if parts.size() >= 3:
			light_color = Color(float(parts[0]), float(parts[1]), float(parts[2])) / 255.0
	light_energy = float(properties.get("energy", light_energy))
	omni_range = float(properties.get("range", omni_range))
	shadow_enabled = bool(properties.get("shadow", shadow_enabled))
