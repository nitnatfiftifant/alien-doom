class_name HumanPostAlertState
extends HumanState

func enter() -> void:
	transition_substate(&"Search" if actor.is_guard() else &"Flee")
