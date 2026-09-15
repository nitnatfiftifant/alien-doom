class_name HumanController
extends CharacterBody3D

@export_enum("Worker", "Guard") var role := "Worker":
	set(value):
		# Old Engineer markers are civilians; only Guard can use combat.
		role = "Guard" if value == "Guard" else "Worker"
		if is_node_ready():
			_refresh_role()
@export var targetname := ""
@export var patrol_id := ""
@export var vitality_config: HumanVitalityConfig
@export var ai_config: HumanAIConfig
@onready var stress: StressComponent = $StressComponent
@onready var perception: PerceptionComponent = $PerceptionComponent
@onready var navigation: NavigationAgent3D = $NavigationAgent3D
@onready var health: HealthComponent = $HealthComponent
@onready var state_machine: HumanStateMachine = $HumanStateMachine
@onready var combat: RangedCombatComponent = $RangedCombatComponent
@onready var state_indicator: MeshInstance3D = $StateIndicator
@onready var ragdoll: HumanRagdollComponent = $HumanRagdollComponent
@onready var awareness: HumanAwarenessMemory = $HumanAwarenessMemory
var _map_properties: Dictionary = {}
var _has_unique_ai_config := false

func _func_godot_apply_properties(properties: Dictionary) -> void:
	_map_properties = properties.duplicate()
	role = str(properties.get("role", role))
	targetname = str(properties.get("targetname", targetname))
	patrol_id = str(properties.get("patrol_id", patrol_id))
	if is_node_ready():
		_apply_map_ai_properties()

func _ready() -> void:
	add_to_group("humans")
	if vitality_config != null:
		health.configure(vitality_config.maximum_health)
	perception.stimulus_detected.connect(_on_stimulus)
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	stress.state_changed.connect(_on_stress_state_changed)
	stress.state_changed.connect(_update_state_color)
	_apply_map_ai_properties()
	_refresh_role()
	_update_state_color(StressComponent.State.CALM, StressComponent.State.CALM)

func is_guard() -> bool:
	return role == "Guard"

func _refresh_role() -> void:
	$HumanPresentationComponent.refresh_role()
	$PerceptionComponent/GuardViewCone.refresh_role()
	if state_machine.current != null:
		state_machine.current.exit()
		state_machine.current.enter()

func _apply_map_ai_properties() -> void:
	if ai_config == null or _map_properties.is_empty():
		return
	if not _has_unique_ai_config:
		ai_config = ai_config.duplicate(true) as HumanAIConfig
		_has_unique_ai_config = true
	ai_config.move_speed = _map_float(&"ai_move_speed", ai_config.move_speed)
	ai_config.acceleration = _map_float(&"ai_acceleration", ai_config.acceleration)
	ai_config.turn_speed = _map_float(&"ai_turn_speed", ai_config.turn_speed)
	ai_config.search_duration = _map_float(&"search_duration", ai_config.search_duration)
	ai_config.search_radius = _map_float(&"search_radius", ai_config.search_radius)
	ai_config.flee_distance = _map_float(&"flee_distance", ai_config.flee_distance)
	ai_config.stress_share_radius = _map_float(&"stress_share_radius", ai_config.stress_share_radius)
	perception.direct_view_distance = _map_float(&"direct_view_distance", perception.direct_view_distance)
	perception.peripheral_distance = _map_float(&"peripheral_distance", perception.peripheral_distance)
	perception.touch_distance = _map_float(&"touch_distance", perception.touch_distance)
	perception.hearing_distance = _map_float(&"hearing_distance", perception.hearing_distance)
	perception.direct_half_angle = _map_float(&"direct_half_angle", perception.direct_half_angle)
	perception.peripheral_half_angle = _map_float(&"peripheral_half_angle", perception.peripheral_half_angle)
	stress.decay_delay = _map_float(&"stress_decay_delay", stress.decay_delay)
	stress.alert_to_calm_seconds = _map_float(&"stress_recovery_seconds", stress.alert_to_calm_seconds)

func _map_float(property: StringName, fallback: float) -> float:
	return float(_map_properties.get(property, fallback))

func _physics_process(delta: float) -> void:
	stress.tick(delta)
	awareness.tick(delta)
	var creature := get_tree().get_first_node_in_group("creature") as CreatureController
	for corpse in get_tree().get_nodes_in_group("corpses"):
		perception.evaluate_target(corpse as Node3D, delta, true)
	awareness.track_creature(creature, perception.evaluate_target(creature, delta))
	_share_stress()
	state_machine.physics_update(delta)
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = -0.5
	move_and_slide()

func _on_stimulus(position: Vector3, strength: float, is_corpse: bool) -> void:
	awareness.remember_stimulus(position, is_corpse)
	if is_corpse:
		stress.add_stress_capped(strength, 74.9)
	else:
		stress.add_stress(strength)

func _share_stress() -> void:
	if stress.state < StressComponent.State.POST_ALERT or ai_config == null:
		return
	for human in get_tree().get_nodes_in_group("humans"):
		if human != self and global_position.distance_to(human.global_position) <= ai_config.stress_share_radius:
			if stress.value > human.stress.value and not human.awareness.creature_visible:
				human.awareness.remember_stimulus(awareness.last_known_position, awareness.last_stimulus_kind == HumanAwarenessMemory.StimulusKind.CORPSE)
			human.stress.synchronize_upwards(stress.value)

func navigate_to_last_stimulus(flee: bool) -> void:
	if flee:
		var away := global_position - awareness.last_known_position
		away.y = 0.0
		if away.is_zero_approx():
			away = global_basis.z
		navigation.target_position = global_position + away.normalized() * ai_config.flee_distance
	else:
		navigation.target_position = awareness.last_known_position

func follow_navigation(_flee := false, delta := 1.0 / 60.0) -> void:
	var next_position := navigation.target_position
	if navigation.get_navigation_map().is_valid() and not navigation.is_navigation_finished():
		next_position = navigation.get_next_path_position()
	var direction := next_position - global_position
	direction.y = 0.0
	direction = direction.normalized()
	if direction.is_zero_approx():
		direction = awareness.last_known_position - global_position
		direction.y = 0.0
		direction = direction.normalized()
	var desired: Vector3 = direction * float(ai_config.move_speed)
	velocity.x = move_toward(velocity.x, desired.x, ai_config.acceleration * delta)
	velocity.z = move_toward(velocity.z, desired.z, ai_config.acceleration * delta)
	if not direction.is_zero_approx():
		var desired_basis := Basis.looking_at(direction, Vector3.UP)
		global_basis = global_basis.slerp(desired_basis, clampf(ai_config.turn_speed * delta, 0.0, 1.0)).orthonormalized()
	_try_open_door(direction)

func has_reached_navigation_target() -> bool:
	return global_position.distance_to(navigation.target_position) <= ai_config.arrival_distance

func face_position(position: Vector3, delta: float) -> void:
	var direction := position - global_position
	direction.y = 0.0
	if direction.is_zero_approx():
		return
	var desired_basis := Basis.looking_at(direction.normalized(), Vector3.UP)
	global_basis = global_basis.slerp(desired_basis, clampf(ai_config.turn_speed * delta, 0.0, 1.0)).orthonormalized()

func slow_down() -> void:
	var step: float = float(ai_config.acceleration) / 60.0 if ai_config != null else 0.3
	velocity.x = move_toward(velocity.x, 0.0, step)
	velocity.z = move_toward(velocity.z, 0.0, step)

func _on_stress_state_changed(_previous: StressComponent.State, current: StressComponent.State) -> void:
	state_machine.transition_to(current)

func _try_open_door(direction: Vector3) -> void:
	if direction.is_zero_approx(): return
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, global_position + Vector3.UP + direction * 1.2)
	query.exclude = [self]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider.has_method("interact"):
		hit.collider.call("interact", self)

func _update_state_color(_previous: StressComponent.State, current: StressComponent.State) -> void:
	var colors := [Color(0.2, 0.8, 0.25), Color(1, 0.85, 0.1), Color(1, 0.4, 0.05), Color(0.9, 0.05, 0.05)]
	var material := StandardMaterial3D.new()
	material.albedo_color = colors[current]
	state_indicator.material_override = material

func _on_died(_instigator: Node) -> void:
	(get_node("/root/NOISE") as NoiseBus).emit_noise(global_position, 1.0, self)
	set_physics_process(false)
	remove_from_group("humans")
	add_to_group("dead_humans")
	add_to_group("corpses")
	$PerceptionComponent/GuardViewCone.refresh_role()
	collision_layer = 0
	collision_mask = 0
	$CollisionShape3D.set_deferred("disabled", true)
	state_indicator.visible = false
	$HumanAnimationComponent.set_process(false)
	ragdoll.activate(velocity)

func _on_damaged(_amount: float, instigator: Node) -> void:
	if instigator is Node3D:
		awareness.remember_stimulus(instigator.global_position, false)
	stress.add_stress(100.0)
