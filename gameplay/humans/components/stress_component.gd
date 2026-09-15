class_name StressComponent
extends Node

signal state_changed(previous: State, current: State)
signal stress_changed(value: float)

enum State { CALM, CAUTIOUS, POST_ALERT, ALERT }

@export var decay_delay := 15.0
@export var alert_to_calm_seconds := 60.0
var value := 0.0
var state := State.CALM
var time_since_stimulus := INF

func add_stress(amount: float) -> void:
	if amount <= 0.0:
		return
	value = clampf(value + amount, 0.0, 100.0)
	time_since_stimulus = 0.0
	_update_state()
	stress_changed.emit(value)

func add_stress_capped(amount: float, maximum: float) -> void:
	if amount <= 0.0:
		return
	# A corpse cannot create full alert or reduce an existing full alert.
	value = maxf(value, clampf(value + amount, 0.0, maximum))
	time_since_stimulus = 0.0
	_update_state()
	stress_changed.emit(value)

func cap_stress(maximum: float) -> void:
	value = minf(value, maximum)
	_update_state()

func tick(delta: float) -> void:
	time_since_stimulus += delta
	if time_since_stimulus < decay_delay:
		return
	value = maxf(0.0, value - (100.0 / alert_to_calm_seconds) * delta)
	_update_state()
	stress_changed.emit(value)

func synchronize_upwards(other_value: float) -> void:
	if other_value > value:
		add_stress(other_value - value)

func _update_state() -> void:
	var next := State.CALM
	if value >= 75.0:
		next = State.ALERT
	elif value >= 45.0:
		next = State.POST_ALERT
	elif value >= 15.0:
		next = State.CAUTIOUS
	if next != state:
		var previous := state
		state = next
		state_changed.emit(previous, state)
