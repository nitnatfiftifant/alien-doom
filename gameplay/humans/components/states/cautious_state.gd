class_name HumanCautiousState
extends HumanState

func enter() -> void:
	actor.navigate_to_last_stimulus(false)

func physics_update(_delta: float) -> void:
	actor.follow_navigation(false)

