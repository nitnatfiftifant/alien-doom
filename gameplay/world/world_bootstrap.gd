class_name WorldBootstrap
extends Node

@export var map: FuncGodotMap
@export var creature_scene: PackedScene
@export var human_scene: PackedScene
@export var nest_scene: PackedScene
var creature: CreatureController
var spawn_transform := Transform3D.IDENTITY

func _ready() -> void:
	call_deferred("spawn_from_map")

func spawn_from_map() -> void:
	var world_root := map.get_parent()
	for marker in map.get_children():
		if marker is AlienDoomPlayerStart:
			spawn_transform = marker.global_transform
			creature = creature_scene.instantiate() as CreatureController
			creature.initial_transform = spawn_transform
			world_root.add_child(creature)
			creature.global_transform = spawn_transform
		elif marker is AlienDoomHumanSpawn:
			var human := human_scene.instantiate() as HumanController
			world_root.add_child(human)
			human.global_transform = marker.global_transform
			human.role = marker.role
			human.targetname = marker.targetname
			human.patrol_id = marker.patrol_id
		elif marker is AlienDoomNestMarker:
			var nest := nest_scene.instantiate() as CreatureNest
			world_root.add_child(nest)
			nest.global_transform = marker.global_transform
