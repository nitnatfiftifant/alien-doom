class_name HumanAlertState
extends HumanState

func enter() -> void:
	transition_substate(&"Combat" if actor.is_guard() else &"Flee")
