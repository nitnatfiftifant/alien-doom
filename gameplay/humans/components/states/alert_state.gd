class_name HumanAlertState
extends HumanState

func enter() -> void:
	transition_substate(&"Flee" if actor.role == "Worker" else &"Combat")
