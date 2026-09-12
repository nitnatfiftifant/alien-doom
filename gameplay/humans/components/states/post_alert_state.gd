class_name HumanPostAlertState
extends HumanState

func enter() -> void:
	transition_substate(&"Flee" if actor.role == "Worker" else &"Search")
