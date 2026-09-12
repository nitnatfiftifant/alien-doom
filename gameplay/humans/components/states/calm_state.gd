class_name HumanCalmState
extends HumanState

func physics_update(_delta: float) -> void:
	actor.slow_down()

