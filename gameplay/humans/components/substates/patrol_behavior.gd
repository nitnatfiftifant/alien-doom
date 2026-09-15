class_name HumanPatrolBehavior
extends HumanBehaviorState

var points: Array[HumanPatrolPoint] = []
var point_index := 0
var waiting := false
var wait_remaining := 0.0
var route_retry := 0.0
var route_id := ""

func enter() -> void:
	points.clear()
	point_index = 0
	waiting = false
	route_retry = 0.0
	route_id = actor.patrol_id

func physics_update(delta: float) -> void:
	if actor.patrol_id.is_empty():
		actor.slow_down()
		return
	if route_id != actor.patrol_id or (not points.is_empty() and not is_instance_valid(points[point_index])):
		enter()
	if points.is_empty():
		route_retry -= delta
		if route_retry > 0.0:
			actor.slow_down()
			return
		route_retry = 0.5
		_find_route()
		if points.is_empty():
			actor.slow_down()
			return
	if waiting:
		actor.slow_down()
		wait_remaining -= delta
		if wait_remaining <= 0.0:
			point_index = (point_index + 1) % points.size()
			waiting = false
			actor.navigation.target_position = points[point_index].global_position
		return
	actor.navigation.target_position = points[point_index].global_position
	if actor.has_reached_navigation_target():
		waiting = true
		wait_remaining = points[point_index].wait_seconds
		actor.slow_down()
	else:
		actor.follow_navigation(false, delta)

func _find_route() -> void:
	# Map point scenes can enter the tree after the guard, so resolve lazily.
	for candidate in get_tree().get_nodes_in_group("human_patrol_points"):
		if candidate is HumanPatrolPoint and candidate.patrol_id == actor.patrol_id:
			points.append(candidate)
	points.sort_custom(func(a: HumanPatrolPoint, b: HumanPatrolPoint): return a.point_index < b.point_index)
	var nearest_distance := INF
	for index in points.size():
		var distance := actor.global_position.distance_squared_to(points[index].global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			point_index = index
