class_name CreatureController
extends CharacterBody3D

const MOVEMENT_PROPERTIES: Array[StringName] = [
	&"run_speed",
	&"sneak_speed",
	&"acceleration",
	&"jump_impulse",
	&"jump_forward_impulse",
	&"air_acceleration",
	&"air_max_speed",
	&"gravity_strength",
	&"orientation_speed",
	&"air_orientation_speed",
	&"stick_velocity",
	&"probe_length",
]

@export_group("Look")
@export var mouse_sensitivity := 0.0025

@export_group("Movement")
@export var run_speed := 8.0:
	set(value): run_speed = value; _sync_motor_prop(&"run_speed", value)
@export var sneak_speed := 3.0:
	set(value): sneak_speed = value; _sync_motor_prop(&"sneak_speed", value)
@export var acceleration := 28.0:
	set(value): acceleration = value; _sync_motor_prop(&"acceleration", value)
@export var jump_impulse := 13.0:
	set(value): jump_impulse = value; _sync_motor_prop(&"jump_impulse", value)
@export var jump_forward_impulse := 3.5:
	set(value): jump_forward_impulse = value; _sync_motor_prop(&"jump_forward_impulse", value)
@export var air_acceleration := 14.0:
	set(value): air_acceleration = value; _sync_motor_prop(&"air_acceleration", value)
@export var air_max_speed := 12.0:
	set(value): air_max_speed = value; _sync_motor_prop(&"air_max_speed", value)
@export var gravity_strength := 22.0:
	set(value): gravity_strength = value; _sync_motor_prop(&"gravity_strength", value)
@export var orientation_speed := 10.0:
	set(value): orientation_speed = value; _sync_motor_prop(&"orientation_speed", value)
@export var air_orientation_speed := 8.0:
	set(value): air_orientation_speed = value; _sync_motor_prop(&"air_orientation_speed", value)
@export var stick_velocity := 3.5:
	set(value): stick_velocity = value; _sync_motor_prop(&"stick_velocity", value)
@export var probe_length := 1.2:
	set(value): probe_length = value; _sync_motor_prop(&"probe_length", value)

@onready var camera_pivot: Node3D = $CameraPivot
@onready var motor: SurfaceMotor = $SurfaceMotor
@onready var abilities: CreatureAbilities = $CreatureAbilities
@onready var health: HealthComponent = $HealthComponent
@onready var carry: CarryComponent = $CarryComponent
@onready var ragdoll_pusher: RagdollPusherComponent = $RagdollPusherComponent
var sneak := false
var initial_transform := Transform3D.IDENTITY

func _func_godot_apply_properties(properties: Dictionary) -> void:
	for prop in MOVEMENT_PROPERTIES:
		if properties.has(prop):
			set(prop, float(properties[prop]))
	if bool(properties.get("ceiling_spawn", false)) and motor != null:
		motor.surface_up = Vector3.DOWN
		motor.surface_forward = Vector3.FORWARD

func _ready() -> void:
	if initial_transform == Transform3D.IDENTITY:
		initial_transform = global_transform
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	add_to_group("creature")
	_sync_motor_parameters()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)

func _sync_motor_prop(prop: StringName, value: float) -> void:
	if motor != null:
		motor.set(prop, value)

func _sync_motor_parameters() -> void:
	if motor == null:
		return
	for prop in MOVEMENT_PROPERTIES:
		motor.set(prop, get(prop))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_object_local(Vector3.UP, -event.relative.x * mouse_sensitivity)
		camera_pivot.rotate_object_local(Vector3.RIGHT, -event.relative.y * mouse_sensitivity)
		camera_pivot.rotation.x = clampf(camera_pivot.rotation.x, -1.45, 1.45)
	if event.is_action_pressed(&"bite"):
		abilities.bite(self)
	if event.is_action_pressed(&"acid"):
		abilities.spit_acid(self)
	if event.is_action_pressed(&"interact"):
		carry.toggle(self)
	if event.is_action_pressed(&"ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	sneak = Input.is_action_pressed(&"sneak")
	var input_vector := Input.get_vector(&"move_left", &"move_right", &"move_back", &"move_forward")
	var jump_pressed := Input.is_action_just_pressed(&"jump")
	var floor_detach_pressed := Input.is_action_just_pressed(&"floor_detach")
	motor.physics_step(input_vector, sneak, jump_pressed, delta, floor_detach_pressed)
	carry.physics_step(delta)
	motor.movement_multiplier = carry.get_movement_multiplier()
	ragdoll_pusher.physics_step()
	abilities.tick(delta)
	if input_vector.length_squared() > 0.1:
		_emit_noise(0.12 if sneak else 0.75)

func _emit_noise(loudness: float) -> void:
	var noise := get_node_or_null("/root/NOISE") as NoiseBus
	if noise != null:
		noise.emit_noise(global_position, loudness, self)

func _on_damaged(_amount: float, _instigator: Node) -> void:
	_emit_noise(1.0)

func _horizontal_forward(source_basis: Basis) -> Vector3:
	var forward := -source_basis.z
	forward.y = 0.0
	return forward.normalized() if not forward.is_zero_approx() else Vector3.FORWARD

func _on_died(_instigator: Node) -> void:
	var nest := get_tree().get_first_node_in_group("creature_nest") as Node3D
	var respawn_transform := Transform3D(Basis.looking_at(_horizontal_forward(nest.global_basis), Vector3.UP), nest.global_position + Vector3.UP * 0.6) if nest else initial_transform
	global_transform = respawn_transform
	motor.reset_orientation(_horizontal_forward(respawn_transform.basis))
	camera_pivot.rotation = Vector3.ZERO
	velocity = Vector3.ZERO
	health.restore()
