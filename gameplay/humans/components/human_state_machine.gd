class_name HumanStateMachine
extends Node

signal transitioned(previous: StressComponent.State, current: StressComponent.State)

@export var actor: HumanController
var current: HumanState
var states: Dictionary[StressComponent.State, HumanState] = {}

func _ready() -> void:
	for child in get_children():
		if child is HumanState:
			child.setup(actor)
			states[child.state_id] = child
	transition_to(StressComponent.State.CALM)

func transition_to(next_id: StressComponent.State) -> void:
	var next := states.get(next_id) as HumanState
	if next == null or next == current:
		return
	var previous_id := current.state_id if current else StressComponent.State.CALM
	if current:
		current.exit()
	current = next
	current.enter()
	transitioned.emit(previous_id, current.state_id)

func physics_update(delta: float) -> void:
	if current:
		current.physics_update(delta)

