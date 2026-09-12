class_name HumanFleeBehavior
extends HumanBehaviorState

func enter() -> void:
	actor.navigate_to_last_stimulus(true)

func physics_update(_delta: float) -> void:
	actor.follow_navigation(true)
