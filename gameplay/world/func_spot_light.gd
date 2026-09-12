@tool
class_name FuncSpotLight
extends SpotLight3D

func _func_godot_apply_properties(properties: Dictionary) -> void:
	var color_value = properties.get("_color", light_color)
	if color_value is Color:
		light_color = color_value
	light_energy = float(properties.get("energy", light_energy))
	spot_range = float(properties.get("range", spot_range))
	spot_angle = float(properties.get("cone_angle", spot_angle))
	shadow_enabled = bool(properties.get("shadow", shadow_enabled))
