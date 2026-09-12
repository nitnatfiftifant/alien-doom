class_name HumanController
extends CharacterBody3D

@export_enum("Worker", "Guard", "Engineer") var role := "Worker"
@export var move_speed := 3.2
@export var targetname := ""
@export var vitality_config: HumanVitalityConfig
@onready var stress: StressComponent = $StressComponent
@onready var perception: PerceptionComponent = $PerceptionComponent
@onready var navigation: NavigationAgent3D = $NavigationAgent3D
@onready var health: HealthComponent = $HealthComponent
@onready var state_machine: HumanStateMachine = $HumanStateMachine
@onready var combat: RangedCombatComponent = $RangedCombatComponent
@onready var state_indicator: MeshInstance3D = $StateIndicator
@onready var ragdoll: HumanRagdollComponent = $HumanRagdollComponent
var last_stimulus_position := Vector3.ZERO

func _func_godot_apply_properties(properties: Dictionary) -> void:
	role = str(properties.get("role", role))
	targetname = str(properties.get("targetname", targetname))

func _ready() -> void:
	add_to_group("humans")
	if vitality_config != null:
		health.configure(vitality_config.maximum_health)
	perception.stimulus_detected.connect(_on_stimulus)
	health.died.connect(_on_died)
	stress.state_changed.connect(_on_stress_state_changed)
	stress.state_changed.connect(_update_state_color)
	_update_state_color(StressComponent.State.CALM, StressComponent.State.CALM)

func _physics_process(delta: float) -> void:
	stress.tick(delta)
	var creature := get_tree().get_first_node_in_group("creature") as Node3D
	perception.evaluate_target(creature, delta)
	for corpse in get_tree().get_nodes_in_group("corpses"):
		perception.evaluate_target(corpse as Node3D, delta, true)
	_share_stress()
	state_machine.physics_update(delta)
	if role == "Guard" and stress.state == StressComponent.State.ALERT:
		combat.tick(creature as CreatureController, delta)
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = -0.5
	move_and_slide()

func _on_stimulus(position: Vector3, strength: float, is_corpse: bool) -> void:
	last_stimulus_position = position
	stress.add_stress(strength)
	if is_corpse:
		stress.cap_stress(74.9)

func _share_stress() -> void:
	if stress.state < StressComponent.State.POST_ALERT:
		return
	for human in get_tree().get_nodes_in_group("humans"):
		if human != self and global_position.distance_to(human.global_position) <= 8.0:
			human.stress.synchronize_upwards(stress.value)

func navigate_to_last_stimulus(flee: bool) -> void:
	navigation.target_position = global_position - (last_stimulus_position - global_position) if flee else last_stimulus_position

func follow_navigation(flee: bool) -> void:
	navigation.target_position = last_stimulus_position
	var next_position := last_stimulus_position
	if navigation.get_navigation_map().is_valid() and not navigation.is_navigation_finished():
		next_position = navigation.get_next_path_position()
	var direction := next_position - global_position
	direction.y = 0.0
	direction = direction.normalized()
	if direction.is_zero_approx():
		direction = last_stimulus_position - global_position
		direction.y = 0.0
		direction = direction.normalized()
	if flee:
		direction = -direction
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	look_at(global_position + direction, Vector3.UP)
	_try_open_door(direction)

func slow_down() -> void:
	velocity.x = move_toward(velocity.x, 0.0, 0.3)
	velocity.z = move_toward(velocity.z, 0.0, 0.3)

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
	collision_layer = 0
	collision_mask = 0
	state_indicator.visible = false
	$HumanAnimationComponent.set_process(false)
	ragdoll.activate(velocity)
