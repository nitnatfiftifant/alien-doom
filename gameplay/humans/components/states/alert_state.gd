class_name HumanAlertState
extends HumanState

func enter() -> void:
	actor.navigate_to_last_stimulus(actor.role == "Worker")

func physics_update(_delta: float) -> void:
	actor.follow_navigation(actor.role == "Worker")

