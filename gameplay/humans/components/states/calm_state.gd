class_name HumanCalmState
extends HumanState

func enter() -> void:
	transition_substate(&"Patrol" if actor.role == "Guard" else &"Idle")
