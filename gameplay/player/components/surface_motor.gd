class_name SurfaceMotor
extends Node

@export var body: CharacterBody3D
@export var camera_pivot: Node3D
@export var adhesion_probe: RayCast3D
@export var run_speed := 8.0
@export var sneak_speed := 3.0
@export var acceleration := 28.0
@export var gravity_strength := 22.0
@export var orientation_speed := 10.0
@export var air_orientation_speed := 8.0
@export var jump_impulse := 21.0
@export var stick_velocity := 3.5
@export var probe_length := 1.2

var surface_up := Vector3.UP
var surface_forward := Vector3.FORWARD
var previous_surface_up := Vector3.UP

var is_airborne := false
var attached := true
var coyote_timer := 0.0
var transition_cooldown := 0.0
var jump_cooldown := 0.0

func reset_orientation(facing: Vector3 = Vector3.FORWARD) -> void:
	surface_up = Vector3.UP
	previous_surface_up = Vector3.UP
	surface_forward = facing.slide(Vector3.UP).normalized()
	if surface_forward.is_zero_approx():
		surface_forward = Vector3.FORWARD
	is_airborne = false
	attached = true
	coyote_timer = 0.0
	transition_cooldown = 0.0
	jump_cooldown = 0.0
	if body != null:
		body.velocity = Vector3.ZERO
		body.up_direction = Vector3.UP

func physics_step(input_vector: Vector2, sneaking: bool, jump_pressed: bool, delta: float, floor_detach_pressed := false) -> void:
	if body == null:
		return

	transition_cooldown = maxf(0.0, transition_cooldown - delta)
	jump_cooldown = maxf(0.0, jump_cooldown - delta)
	coyote_timer = maxf(0.0, coyote_timer - delta)

	# 1. Handle Floor Detach (Key C)
	if floor_detach_pressed and (attached or not is_airborne):
		attached = false
		is_airborne = true
		coyote_timer = 0.0
		jump_cooldown = 0.25
		# Instantly target floor upright orientation and kill stick velocity
		surface_up = Vector3.UP
		previous_surface_up = Vector3.UP
		body.velocity = body.velocity.slide(surface_up)

	# 2. Camera-relative movement axes on current surface plane
	var camera_forward := -camera_pivot.global_basis.z
	camera_forward = camera_forward.slide(surface_up).normalized()
	if not camera_forward.is_zero_approx():
		surface_forward = camera_forward
	var forward := surface_forward.slide(surface_up).normalized()
	if forward.is_zero_approx():
		forward = _perpendicular_to(surface_up)
	var right := forward.cross(surface_up).normalized()
	var desired := (right * input_vector.x + forward * input_vector.y).normalized()

	# 3. Handle Jump (Space)
	if jump_pressed and (attached or coyote_timer > 0.0) and jump_cooldown <= 0.0:
		var jump_direction := surface_up
		if not desired.is_zero_approx():
			jump_direction = (surface_up * 0.85 + desired * 0.25).normalized()
		body.velocity = body.velocity.slide(surface_up) + jump_direction * jump_impulse
		attached = false
		is_airborne = true
		coyote_timer = 0.0
		jump_cooldown = 0.2

	# 4. Surface search and adherence
	if not is_airborne and jump_cooldown <= 0.0:
		var contact := _find_surface(desired)
		if not contact.is_empty():
			attached = true
			coyote_timer = 0.08
			var new_normal: Vector3 = contact.normal.normalized()
			if contact.get("is_wrap", false):
				# Outer (convex) corner wrap
				_apply_surface_transition(new_normal, true)
			elif contact.get("transitioned", false):
				_apply_surface_transition(new_normal, false)
		else:
			if coyote_timer <= 0.0:
				attached = false
				is_airborne = true
	elif is_airborne:
		attached = false

	# 5. Orientation update
	_update_orientation(delta)

	# 6. Velocity computation & motion
	var speed := sneak_speed if sneaking else run_speed
	if attached:
		var tangent_velocity := body.velocity.slide(surface_up)
		tangent_velocity = tangent_velocity.move_toward(desired * speed, acceleration * delta)
		var normal_velocity := -surface_up * stick_velocity
		body.velocity = tangent_velocity + normal_velocity
		body.up_direction = surface_up
		body.floor_snap_length = 0.4
	else:
		# Airborne: preserve existing velocity (including jump impulse!), apply gravity and air steering
		var air_horiz := body.velocity.slide(Vector3.UP)
		if not desired.is_zero_approx():
			air_horiz = air_horiz.move_toward(desired.slide(Vector3.UP).normalized() * speed, (acceleration * 0.25) * delta)
		var air_vert := body.velocity.project(Vector3.UP) + Vector3.DOWN * gravity_strength * delta
		body.velocity = air_horiz + air_vert
		body.up_direction = Vector3.UP

	body.move_and_slide()

	# 7. Post-move collision handling
	if attached:
		_adopt_slide_surface(desired)
	elif is_airborne and jump_cooldown <= 0.0:
		_check_airborne_landing(desired)

func _find_surface(desired: Vector3) -> Dictionary:
	var space := body.get_world_3d().direct_space_state
	var origin := body.global_position

	# 1. Primary downward ray along -surface_up
	var down_query := PhysicsRayQueryParameters3D.create(origin, origin - surface_up * probe_length, 1)
	down_query.exclude = [body]
	var down_hit := space.intersect_ray(down_query)
	if not down_hit.is_empty():
		down_hit["transitioned"] = false
		down_hit["is_wrap"] = false
		return down_hit

	# 2. Forward-down angled probe (catches slopes and small drops ahead)
	if not desired.is_zero_approx():
		var forward_down_target := origin + desired * 0.4 - surface_up * probe_length
		var forward_down_query := PhysicsRayQueryParameters3D.create(origin, forward_down_target, 1)
		forward_down_query.exclude = [body]
		var forward_down_hit := space.intersect_ray(forward_down_query)
		if not forward_down_hit.is_empty():
			forward_down_hit["transitioned"] = false
			forward_down_hit["is_wrap"] = false
			return forward_down_hit

	# 3. Outer (convex) corner wrap probe:
	# Starts ahead of the ledge and casts back into the wrap-around face
	if not desired.is_zero_approx():
		var wrap_start := origin + desired * 0.45 - surface_up * 0.45
		var wrap_target := wrap_start - desired * 0.95
		var wrap_query := PhysicsRayQueryParameters3D.create(wrap_start, wrap_target, 1)
		wrap_query.exclude = [body]
		var wrap_hit := space.intersect_ray(wrap_query)
		if not wrap_hit.is_empty():
			var hit_norm: Vector3 = wrap_hit.normal.normalized()
			if hit_norm.dot(surface_up) < 0.7:
				wrap_hit["transitioned"] = true
				wrap_hit["is_wrap"] = true
				return wrap_hit

	return {}

func _adopt_slide_surface(desired: Vector3) -> void:
	if desired.is_zero_approx() or transition_cooldown > 0.0:
		return

	var best_normal := Vector3.ZERO
	var strongest_opposition := 0.35
	for index in body.get_slide_collision_count():
		var collision := body.get_slide_collision(index)
		var normal := collision.get_normal().normalized()
		var opposition := -desired.dot(normal)
		if opposition > strongest_opposition and normal.dot(surface_up) < 0.85:
			# Anti-jitter: reject immediate bounce back to previous normal unless strongly opposed
			if normal.dot(previous_surface_up) > 0.85 and opposition < 0.75:
				continue
			if opposition > strongest_opposition:
				strongest_opposition = opposition
				best_normal = normal

	if best_normal.is_zero_approx():
		return

	_apply_surface_transition(best_normal, false)
	body.velocity = body.velocity.slide(surface_up) - surface_up * stick_velocity

func _apply_surface_transition(new_normal: Vector3, is_wrap := false) -> void:
	previous_surface_up = surface_up
	surface_up = new_normal
	transition_cooldown = 0.15
	var base_forward := -previous_surface_up if is_wrap else previous_surface_up
	var transition_forward := base_forward.slide(surface_up).normalized()
	if not transition_forward.is_zero_approx():
		surface_forward = transition_forward

func _check_airborne_landing(desired: Vector3) -> void:
	# Check slide collisions for floor or intentional wall landing
	for index in body.get_slide_collision_count():
		var collision := body.get_slide_collision(index)
		var normal := collision.get_normal().normalized()
		if normal.y > 0.5:
			_land_on_surface(normal)
			return
		elif not desired.is_zero_approx() and -desired.dot(normal) > 0.4:
			_land_on_surface(normal)
			return

	# Proximity ground raycast check
	var space := body.get_world_3d().direct_space_state
	var origin := body.global_position
	var ground_query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * 0.9, 1)
	ground_query.exclude = [body]
	var ground_hit := space.intersect_ray(ground_query)
	if not ground_hit.is_empty():
		var normal: Vector3 = ground_hit.normal.normalized()
		if normal.y > 0.5:
			_land_on_surface(normal)

func _land_on_surface(normal: Vector3) -> void:
	surface_up = normal
	is_airborne = false
	attached = true
	coyote_timer = 0.08
	transition_cooldown = 0.15
	surface_forward = surface_forward.slide(surface_up).normalized()
	if surface_forward.is_zero_approx():
		surface_forward = _perpendicular_to(surface_up)

func _update_orientation(delta: float) -> void:
	if is_airborne:
		# Smoothly right the creature towards Vector3.UP in mid-air
		if surface_up.dot(Vector3.UP) < -0.98:
			var perturb_axis := surface_forward if not surface_forward.is_zero_approx() else Vector3.FORWARD
			surface_up = surface_up.rotated(perturb_axis.cross(Vector3.UP).normalized(), 0.1).normalized()
		surface_up = surface_up.slerp(Vector3.UP, clampf(air_orientation_speed * delta, 0.0, 1.0)).normalized()

	var forward := surface_forward.slide(surface_up).normalized()
	if forward.is_zero_approx():
		forward = _perpendicular_to(surface_up)
	surface_forward = forward

	var target := Basis.looking_at(forward, surface_up)
	var speed := air_orientation_speed if is_airborne else orientation_speed
	body.global_basis = body.global_basis.slerp(target, clampf(speed * delta, 0.0, 1.0)).orthonormalized()

func _perpendicular_to(normal: Vector3) -> Vector3:
	var axis := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
	return axis.slide(normal).normalized()
