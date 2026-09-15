class_name HumanPresentationComponent
extends Node

@export var actor: HumanController
@export var visual_root: Node3D
@export var civilian_color := Color(1.0, 0.38, 0.08)
@export var guard_color := Color(0.08, 0.42, 1.0)

var body_meshes: Array[MeshInstance3D] = []

func _ready() -> void:
	# Cache only the body, before the weapon is attached to the skeleton.
	for descendant in visual_root.find_children("*", "MeshInstance3D", true, false):
		body_meshes.append(descendant as MeshInstance3D)
	refresh_role()

func refresh_role() -> void:
	var color := guard_color if actor.is_guard() else civilian_color
	for body_mesh in body_meshes:
		if body_mesh.mesh == null:
			continue
		for surface in body_mesh.mesh.get_surface_count():
			var original := body_mesh.mesh.surface_get_material(surface) as BaseMaterial3D
			var material := original.duplicate() as BaseMaterial3D if original != null else StandardMaterial3D.new()
			material.albedo_color = color
			material.emission_enabled = true
			material.emission = color
			material.emission_energy_multiplier = 0.12
			body_mesh.set_surface_override_material(surface, material)
