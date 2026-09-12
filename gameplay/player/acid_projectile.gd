class_name AcidProjectile
extends Node3D

@export var speed := 18.0
@export var damage := 35.0
@export var maximum_distance := 14.0
@export_flags_3d_physics var collision_mask := 13
@export var splash_radius := 1.1
@export var splash_damage_multiplier := 0.45
@export_group("Impact visual")
@export var impact_radius := 0.12
@export var impact_color := Color(0.25, 1.0, 0.04, 0.8)
@export var impact_emission := Color(0.12, 1.0, 0.02)
@export var impact_duration := 0.22
@export var impact_scale_multiplier := 2.0
@export_group("Queries")
@export_flags_3d_physics var splash_collision_mask := 4
@export_range(1, 64) var maximum_splash_results := 16
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
	if instigator != null:
		query.exclude = [instigator]
	query.collision_mask = collision_mask
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
	var receiver := _find_contract_node(target, &"dissolve_by_acid")
	if receiver != null:
		receiver.call("dissolve_by_acid")
	var health := _find_health(target)
	if health:
		health.apply_damage(damage, instigator)
	_apply_splash(health)
	_spawn_impact_effect()

func _apply_splash(direct_health: HealthComponent) -> void:
	var shape := SphereShape3D.new()
	shape.radius = splash_radius
	var parameters := PhysicsShapeQueryParameters3D.new()
	parameters.shape = shape
	parameters.transform = Transform3D(Basis.IDENTITY, global_position)
	parameters.collision_mask = splash_collision_mask
	if instigator != null:
		parameters.exclude = [instigator]
	var damaged: Array[HealthComponent] = []
	if direct_health != null:
		damaged.append(direct_health)
	for result in get_world_3d().direct_space_state.intersect_shape(parameters, maximum_splash_results):
		var nearby_health := _find_health(result.collider as Node)
		if nearby_health != null and not damaged.has(nearby_health):
			damaged.append(nearby_health)
			nearby_health.apply_damage(damage * splash_damage_multiplier, instigator)

func _find_health(node: Node) -> HealthComponent:
	var current := node
	while current != null:
		if current is HealthComponent:
			return current as HealthComponent
		var child_health := current.get_node_or_null("HealthComponent") as HealthComponent
		if child_health != null:
			return child_health
		current = current.get_parent()
	return null

func _find_contract_node(node: Node, method: StringName) -> Node:
	var current := node
	while current != null:
		if current.has_method(method):
			return current
		current = current.get_parent()
	return null

func _spawn_impact_effect() -> void:
	var effect := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = impact_radius
	mesh.height = impact_radius * 2.0
	effect.mesh = mesh
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = impact_color
	material.emission_enabled = true
	material.emission = impact_emission
	effect.material_override = material
	var effect_parent := get_tree().current_scene
	if effect_parent == null:
		effect_parent = get_parent()
	effect_parent.add_child(effect)
	effect.global_position = global_position
	var tween := effect.create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect, "scale", Vector3.ONE * splash_radius * impact_scale_multiplier, impact_duration)
	tween.tween_property(effect, "transparency", 1.0, impact_duration)
	tween.chain().tween_callback(effect.queue_free)
