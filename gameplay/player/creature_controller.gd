class_name CreatureController
extends CharacterBody3D

@export_group("Look")
@export var mouse_sensitivity := 0.0025

@export_group("Movement")
@export var run_speed := 8.0:
	set(value):
		run_speed = value
		if motor != null: motor.run_speed = value
@export var sneak_speed := 3.0:
	set(value):
		sneak_speed = value
		if motor != null: motor.sneak_speed = value
@export var acceleration := 28.0:
	set(value):
		acceleration = value
		if motor != null: motor.acceleration = value
@export var jump_impulse := 21.0:
	set(value):
		jump_impulse = value
		if motor != null: motor.jump_impulse = value
@export var gravity_strength := 22.0:
	set(value):
		gravity_strength = value
		if motor != null: motor.gravity_strength = value
@export var orientation_speed := 10.0:
	set(value):
		orientation_speed = value
		if motor != null: motor.orientation_speed = value
@export var air_orientation_speed := 8.0:
	set(value):
		air_orientation_speed = value
		if motor != null: motor.air_orientation_speed = value
@export var stick_velocity := 3.5:
	set(value):
		stick_velocity = value
		if motor != null: motor.stick_velocity = value
@export var probe_length := 1.2:
	set(value):
		probe_length = value
		if motor != null: motor.probe_length = value

@onready var camera_pivot: Node3D = $CameraPivot
@onready var motor: SurfaceMotor = $SurfaceMotor
@onready var abilities: CreatureAbilities = $CreatureAbilities
@onready var health: HealthComponent = $HealthComponent
@onready var carry: CarryComponent = $CarryComponent
var sneak := false

func _func_godot_apply_properties(properties: Dictionary) -> void:
	if properties.has("run_speed"): run_speed = float(properties["run_speed"])
	if properties.has("sneak_speed"): sneak_speed = float(properties["sneak_speed"])
	if properties.has("jump_impulse"): jump_impulse = float(properties["jump_impulse"])
	if properties.has("acceleration"): acceleration = float(properties["acceleration"])
	if properties.has("gravity_strength"): gravity_strength = float(properties["gravity_strength"])
	if properties.has("orientation_speed"): orientation_speed = float(properties["orientation_speed"])
	if properties.has("air_orientation_speed"): air_orientation_speed = float(properties["air_orientation_speed"])
	if properties.has("stick_velocity"): stick_velocity = float(properties["stick_velocity"])
	if properties.has("probe_length"): probe_length = float(properties["probe_length"])
	_sync_motor_parameters()
	if bool(properties.get("ceiling_spawn", false)) and motor != null:
		motor.surface_up = Vector3.DOWN
		motor.surface_forward = Vector3.FORWARD

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	add_to_group("creature")
	_sync_motor_parameters()
	_ensure_default_input_actions()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)

func _sync_motor_parameters() -> void:
	if motor == null:
		return
	motor.run_speed = run_speed
	motor.sneak_speed = sneak_speed
	motor.acceleration = acceleration
	motor.jump_impulse = jump_impulse
	motor.gravity_strength = gravity_strength
	motor.orientation_speed = orientation_speed
	motor.air_orientation_speed = air_orientation_speed
	motor.stick_velocity = stick_velocity
	motor.probe_length = probe_length

func _ensure_default_input_actions() -> void:
	_ensure_key_action(&"move_forward", KEY_W, 4194320) # W / Up Arrow
	_ensure_key_action(&"move_back", KEY_S, 4194322) # S / Down Arrow
	_ensure_key_action(&"move_left", KEY_A, 4194319) # A / Left Arrow
	_ensure_key_action(&"move_right", KEY_D, 4194321) # D / Right Arrow
	_ensure_key_action(&"sneak", 4194325) # Shift
	_ensure_key_action(&"jump", KEY_SPACE) # Space
	_ensure_key_action(&"detach", KEY_SPACE) # Space legacy
	_ensure_key_action(&"floor_detach", KEY_C) # C
	_ensure_key_action(&"interact", KEY_E) # E
	_ensure_key_action(&"ui_cancel", 4194305) # Escape
	_ensure_mouse_action(&"bite", MOUSE_BUTTON_LEFT)
	_ensure_mouse_action(&"acid", MOUSE_BUTTON_RIGHT)

func _ensure_key_action(action_name: StringName, physical_key: int, alt_key := -1) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, 0.5)
	if InputMap.action_get_events(action_name).is_empty():
		var event := InputEventKey.new()
		event.physical_keycode = physical_key as Key
		event.keycode = physical_key as Key
		event.device = -1
		InputMap.action_add_event(action_name, event)
		if alt_key != -1:
			var alt_event := InputEventKey.new()
			alt_event.physical_keycode = alt_key as Key
			alt_event.keycode = alt_key as Key
			alt_event.device = -1
			InputMap.action_add_event(action_name, alt_event)

func _ensure_mouse_action(action_name: StringName, button_index: MouseButton) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, 0.5)
	if InputMap.action_get_events(action_name).is_empty():
		var event := InputEventMouseButton.new()
		event.button_index = button_index
		event.device = -1
		InputMap.action_add_event(action_name, event)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_object_local(Vector3.UP, -event.relative.x * mouse_sensitivity)
		camera_pivot.rotate_object_local(Vector3.RIGHT, -event.relative.y * mouse_sensitivity)
		camera_pivot.rotation.x = clampf(camera_pivot.rotation.x, -1.45, 1.45)
	if event.is_action_pressed("bite"):
		abilities.bite(self)
	if event.is_action_pressed("acid"):
		abilities.spit_acid(self)
	if event.is_action_pressed("interact"):
		carry.toggle(self)
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	sneak = Input.is_action_pressed("sneak")
	var input_vector := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var jump_pressed := Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("detach")
	var floor_detach_pressed := Input.is_action_just_pressed("floor_detach")
	motor.physics_step(input_vector, sneak, jump_pressed, delta, floor_detach_pressed)
	abilities.tick(delta)
	if input_vector.length_squared() > 0.1:
		(get_node("/root/NOISE") as NoiseBus).emit_noise(global_position, 0.12 if sneak else 0.75, self)

func _on_damaged(_amount: float, _instigator: Node) -> void:
	(get_node("/root/NOISE") as NoiseBus).emit_noise(global_position, 1.0, self)

func _on_died(_instigator: Node) -> void:
	var nest := get_tree().get_first_node_in_group("creature_nest") as Node3D
	if nest:
		var nest_forward := -nest.global_basis.z
		nest_forward.y = 0.0
		if nest_forward.is_zero_approx():
			nest_forward = Vector3.FORWARD
		global_transform = Transform3D(Basis.looking_at(nest_forward.normalized(), Vector3.UP), nest.global_position + Vector3.UP * 0.6)
		motor.reset_orientation(nest_forward)
	else:
		global_basis = Basis.IDENTITY
		motor.reset_orientation()
	camera_pivot.rotation = Vector3.ZERO
	velocity = Vector3.ZERO
	health.restore()
