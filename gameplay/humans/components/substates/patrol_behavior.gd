class_name HumanPatrolBehavior
extends HumanBehaviorState

func physics_update(_delta: float) -> void:
	# Patrol route data will select destinations; standing guard is the fallback.
	actor.slow_down()
