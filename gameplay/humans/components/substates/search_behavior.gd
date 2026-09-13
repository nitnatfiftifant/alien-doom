class_name HumanSearchBehavior
extends HumanBehaviorState

var elapsed := 0.0
var retarget_timer := 0.0
var search_step := 0

func enter() -> void:
	elapsed = 0.0
	retarget_timer = 0.0
	search_step = 0
	actor.navigation.target_position = actor.awareness.last_known_position

func physics_update(delta: float) -> void:
	elapsed += delta
	retarget_timer -= delta
	if actor.awareness.creature_visible:
		actor.navigation.target_position = actor.awareness.last_known_position
	if retarget_timer <= 0.0 and actor.has_reached_navigation_target():
		retarget_timer = actor.ai_config.search_retarget_seconds
		search_step += 1
		var angle := search_step * GOLDEN_ANGLE
		var offset: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * float(actor.ai_config.search_radius)
		actor.navigation.target_position = actor.awareness.last_known_position + offset
	if elapsed >= actor.ai_config.search_duration:
		actor.slow_down()
	else:
		actor.follow_navigation(false, delta)

const GOLDEN_ANGLE := 2.399963
