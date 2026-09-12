class_name HumanState
extends Node

@export var state_id: StressComponent.State
var actor: HumanController
var current_substate: HumanBehaviorState
var substates: Dictionary[StringName, HumanBehaviorState] = {}

func setup(value: HumanController) -> void:
	actor = value
	for child in get_children():
		if child is HumanBehaviorState:
			child.setup(actor)
			substates[StringName(child.name)] = child

func transition_substate(substate_name: StringName) -> void:
	var next := substates.get(substate_name) as HumanBehaviorState
	if next == null or next == current_substate:
		return
	if current_substate != null:
		current_substate.exit()
	current_substate = next
	current_substate.enter()

func enter() -> void:
	pass

func exit() -> void:
	if current_substate != null:
		current_substate.exit()
	current_substate = null

func physics_update(_delta: float) -> void:
	if current_substate != null:
		current_substate.physics_update(_delta)
