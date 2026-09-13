class_name HumanCombatBehavior
extends HumanBehaviorState

func enter() -> void:
	actor.navigate_to_last_stimulus(false)

func physics_update(_delta: float) -> void:
	if actor.awareness.tracked_creature == null:
		actor.slow_down()
		return
	if actor.awareness.creature_visible:
		actor.slow_down()
		actor.face_position(actor.awareness.tracked_creature.global_position, _delta)
		actor.combat.tick(actor.awareness.tracked_creature, _delta)
	elif actor.has_reached_navigation_target():
		actor.slow_down()
	else:
		actor.navigation.target_position = actor.awareness.last_known_position
		actor.follow_navigation(false, _delta)
