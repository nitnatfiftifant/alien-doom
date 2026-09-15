class_name HumanInvestigateBehavior
extends HumanBehaviorState

func enter() -> void:
	actor.navigate_to_last_stimulus(false)

func physics_update(_delta: float) -> void:
	actor.navigation.target_position = actor.awareness.last_known_position
	if actor.has_reached_navigation_target():
		actor.slow_down()
	else:
		actor.follow_navigation(false, _delta)
