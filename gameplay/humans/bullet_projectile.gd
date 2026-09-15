class_name HumanBulletProjectile
extends Node3D

@export var speed := 180.0
@export var damage := 55.0
@export var maximum_distance := 18.0
@export var maximum_lifetime := 3.0
@export_flags_3d_physics var collision_mask := 15
var direction := Vector3.FORWARD
var instigator: Node
var travelled := 0.0
var age := 0.0
var impacted := false

func _ready() -> void:
	add_to_group("human_bullets")

func launch(origin: Vector3, forward: Vector3, shooter: Node, hit_damage: float, distance: float, bullet_speed: float) -> void:
	global_position = origin
	direction = forward.normalized()
	instigator = shooter
	damage = hit_damage
	maximum_distance = distance
	speed = bullet_speed
	var up := Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	global_basis = Basis.looking_at(direction, up)

func _physics_process(delta: float) -> void:
	if impacted:
		return
	age += delta
	var distance := minf(speed * delta, maximum_distance - travelled)
	if distance <= 0.0 or age > maximum_lifetime:
		queue_free()
		return
	var destination := global_position + direction * distance
	# Sweep the whole travelled segment so a fast bullet cannot skip a thin wall.
	var query := PhysicsRayQueryParameters3D.create(global_position, destination, collision_mask)
	query.hit_from_inside = true
	if is_instance_valid(instigator) and instigator is CollisionObject3D:
		query.exclude = [instigator.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		impacted = true
		global_position = hit.position
		var receiver := (hit.collider as Node).get_node_or_null("HealthComponent") as HealthComponent
		if receiver != null:
			receiver.apply_damage(damage, instigator if is_instance_valid(instigator) else null)
		_spawn_impact()
		queue_free()
		return
	global_position = destination
	travelled += distance
	if travelled >= maximum_distance:
		queue_free()

func _spawn_impact() -> void:
	var effect := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.055
	sphere.height = 0.11
	effect.mesh = sphere
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.65, 0.15)
	effect.material_override = material
	effect.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(effect)
	effect.global_position = global_position
	var tween := effect.create_tween()
	tween.tween_property(effect, "scale", Vector3.ONE * 0.05, 0.12)
	tween.tween_callback(effect.queue_free)
