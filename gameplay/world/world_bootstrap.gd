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
			world_root.add_child(creature)
			creature.global_transform = spawn_transform
			creature.health.died.connect(_on_creature_died)
		elif marker is AlienDoomHumanSpawn:
			var human := human_scene.instantiate() as HumanController
			world_root.add_child(human)
			human.global_transform = marker.global_transform
			human.role = marker.role
			human.targetname = marker.targetname
		elif marker is AlienDoomNestMarker:
			var nest := nest_scene.instantiate() as CreatureNest
			world_root.add_child(nest)
			nest.global_transform = marker.global_transform

func _on_creature_died(_instigator: Node) -> void:
	creature.global_transform = spawn_transform
	creature.velocity = Vector3.ZERO
	creature.health.restore()
