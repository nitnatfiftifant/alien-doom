class_name HumanFleeBehavior
extends HumanBehaviorState

var repath_timer := 0.0
var retreat_direction := Vector3.ZERO
var close_retreat := false
var blocked := false

func enter() -> void:
	repath_timer = 0.0
	close_retreat = false
	blocked = false
	actor.navigate_to_last_stimulus(true)

func exit() -> void:
	actor.civilian_crouching = false

func physics_update(delta: float) -> void:
	var away := (actor.global_position - actor.awareness.last_known_position).slide(Vector3.UP)
	var distance := away.length()
	away = away.normalized() if distance > 0.01 else actor.global_basis.z
	# A wider exit distance prevents alternating stand/crouch at the boundary.
	close_retreat = distance < actor.ai_config.backpedal_distance + (1.0 if close_retreat else 0.0)
	repath_timer -= delta
	if retreat_direction.dot(away) <= 0.0:
		repath_timer = 0.0
	if repath_timer <= 0.0:
		repath_timer = minf(actor.ai_config.flee_repath_seconds, 0.2)
		actor.navigate_to_last_stimulus(true)
		retreat_direction = _find_escape(away)
		blocked = retreat_direction.is_zero_approx()
	actor.civilian_crouching = close_retreat or blocked
	if blocked:
		actor.velocity.x = 0.0
		actor.velocity.z = 0.0
		actor.face_position(actor.awareness.last_known_position, delta)
		actor._try_open_door(away)
		return
	# Recheck the cached route each frame so a moving obstacle cannot be pushed into.
	if not _is_clear(retreat_direction):
		repath_timer = 0.0
		actor.velocity.x = 0.0
		actor.velocity.z = 0.0
		actor.civilian_crouching = true
		actor.face_position(actor.awareness.last_known_position, delta)
		return
	var speed := actor.ai_config.backpedal_speed if close_retreat else actor.ai_config.move_speed
	var desired := retreat_direction * speed
	actor.velocity.x = move_toward(actor.velocity.x, desired.x, actor.ai_config.acceleration * delta)
	actor.velocity.z = move_toward(actor.velocity.z, desired.z, actor.ai_config.acceleration * delta)
	actor.face_position(actor.awareness.last_known_position if close_retreat else actor.global_position + retreat_direction, delta)
	actor._try_open_door(retreat_direction)

func _find_escape(away: Vector3) -> Vector3:
	# All candidates increase distance from the remembered threat, including along walls.
	for angle in [0.0, 45.0, -45.0, 75.0, -75.0]:
		var direction := away.rotated(Vector3.UP, deg_to_rad(angle))
		if _is_clear(direction):
			return direction
	return Vector3.ZERO

func _is_clear(direction: Vector3) -> bool:
	# Lift the capsule slightly for this horizontal probe to avoid treating the floor as a wall.
	var probe := actor.global_transform
	probe.origin.y += 0.04
	return not actor.test_move(probe, direction * 0.65)
