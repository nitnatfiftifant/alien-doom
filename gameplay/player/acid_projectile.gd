class_name AcidProjectile
extends Node3D

@export var speed := 18.0
@export var damage := 35.0
@export var maximum_distance := 14.0
var direction := Vector3.FORWARD
var instigator: Node
var travelled := 0.0

func _ready() -> void:
	add_to_group("acid_projectiles")

func launch(new_direction: Vector3, owner_node: Node, new_damage: float, new_range: float) -> void:
	direction = new_direction.normalized()
	instigator = owner_node
	damage = new_damage
	maximum_distance = new_range

func _physics_process(delta: float) -> void:
	var distance := speed * delta
	var target := global_position + direction * distance
	var query := PhysicsRayQueryParameters3D.create(global_position, target)
	query.exclude = [instigator]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.position
		_apply_hit(hit.collider as Node)
		queue_free()
		return
	global_position = target
	travelled += distance
	if travelled >= maximum_distance:
		queue_free()

func _apply_hit(target: Node) -> void:
	if target == null: return
	if target.has_method("dissolve_by_acid"):
		target.call("dissolve_by_acid")
	var health := target.find_child("HealthComponent", true, false) as HealthComponent
	if health:
		health.apply_damage(damage, instigator)
