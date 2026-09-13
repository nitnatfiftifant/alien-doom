class_name HumanInvestigateBehavior
extends HumanBehaviorState

func enter() -> void:
	actor.navigate_to_last_stimulus(false)

func physics_update(_delta: float) -> void:
	if actor.has_reached_navigation_target():
		actor.slow_down()
	else:
		actor.follow_navigation(false, _delta)
