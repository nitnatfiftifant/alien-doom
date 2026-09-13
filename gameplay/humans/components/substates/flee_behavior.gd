class_name HumanFleeBehavior
extends HumanBehaviorState

var repath_timer := 0.0

func enter() -> void:
	repath_timer = 0.0
	actor.navigate_to_last_stimulus(true)

func physics_update(delta: float) -> void:
	repath_timer -= delta
	if repath_timer <= 0.0:
		repath_timer = actor.ai_config.flee_repath_seconds
		actor.navigate_to_last_stimulus(true)
	actor.follow_navigation(true, delta)
