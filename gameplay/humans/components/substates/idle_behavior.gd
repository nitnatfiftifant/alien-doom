class_name HumanIdleBehavior
extends HumanBehaviorState

func physics_update(_delta: float) -> void:
	actor.slow_down()
