class_name SurfaceMotor
extends Node

@export var body: CharacterBody3D
@export var camera_pivot: Node3D
@export var adhesion_probe: RayCast3D
@export var run_speed := 8.0
@export var sneak_speed := 3.0
@export var acceleration := 28.0
@export var gravity_strength := 22.0
@export var orientation_speed := 16.0
@export var air_orientation_speed := 14.0
@export var jump_impulse := 13.0
@export var jump_forward_impulse := 0.0
@export var air_acceleration := 14.0
@export var air_max_speed := 12.0
@export var stick_velocity := 3.5
@export var probe_length := 1.1
@export_group("Contact timing")
@export var coyote_time := 0.08
@export var jump_recontact_delay := 0.2
@export var detach_recontact_delay := 0.25
@export var surface_transition_delay := 0.12
@export var floor_snap_length := 0.4
@export_group("Corner probing")
@export var forward_probe_distance := 0.4
@export var wrap_forward_offset := 0.65
@export var wrap_down_offset := 0.55
@export var wrap_back_distance := 1.15
@export var wrap_lateral_offset := 0.22
@export var surface_normal_threshold := 0.85
@export var collision_opposition_threshold := 0.25
@export var strong_opposition_threshold := 0.7
@export_group("Landing")
@export var landing_probe_distance := 0.4
@export var floor_normal_threshold := 0.5
@export var wall_landing_opposition := 0.4

var surface_up := Vector3.UP
var surface_forward := Vector3.FORWARD
var previous_surface_up := Vector3.UP

var is_airborne := false
var attached := true
var coyote_timer := 0.0
var transition_cooldown := 0.0
var jump_cooldown := 0.0
var movement_multiplier := 1.0
var wrap_protection_timer := 0.0
var recent_surface_history: Array[Vector3] = []
var corner_dwell_timer := 0.0
var jump_launch_timer := 0.0
var camera_smoothing_offset := Vector3.ZERO
const CAMERA_BASE_POS := Vector3(0, 0.18, 0)

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
	jump_launch_timer = 0.0
	wrap_protection_timer = 0.0
	corner_dwell_timer = 0.0
	camera_smoothing_offset = Vector3.ZERO
	if camera_pivot != null:
		camera_pivot.position = CAMERA_BASE_POS
	recent_surface_history.clear()
	if body != null:
		body.velocity = Vector3.ZERO
		body.up_direction = Vector3.UP
		body.global_basis = Basis.looking_at(surface_forward, surface_up)

func physics_step(input_vector: Vector2, sneaking: bool, jump_pressed: bool, delta: float, floor_detach_pressed := false) -> void:
	if body == null:
		return

	transition_cooldown = maxf(0.0, transition_cooldown - delta)
	jump_cooldown = maxf(0.0, jump_cooldown - delta)
	jump_launch_timer = maxf(0.0, jump_launch_timer - delta)
	coyote_timer = maxf(0.0, coyote_timer - delta)
	wrap_protection_timer = maxf(0.0, wrap_protection_timer - delta)
	corner_dwell_timer = maxf(0.0, corner_dwell_timer - delta)
	if corner_dwell_timer <= 0.0:
		recent_surface_history.clear()

	# 1. Handle Floor Detach (Key C)
	if floor_detach_pressed and (attached or not is_airborne):
		attached = false
		is_airborne = true
		coyote_timer = 0.0
		jump_cooldown = detach_recontact_delay
		jump_launch_timer = 0.04
		surface_up = Vector3.UP
		previous_surface_up = Vector3.UP
		body.velocity = body.velocity.slide(surface_up)

	# 2. Camera-relative movement axes on current surface plane
	if transition_cooldown <= 0.0:
		var camera_forward := -camera_pivot.global_basis.z
		camera_forward = camera_forward.slide(surface_up).normalized()
		if not camera_forward.is_zero_approx():
			surface_forward = camera_forward
	var forward := surface_forward.slide(surface_up).normalized()
	if forward.is_zero_approx():
		forward = _perpendicular_to(surface_up)
	var right := forward.cross(surface_up).normalized()
	var desired := (right * input_vector.x + forward * input_vector.y).normalized()

	# 3. Handle Jump (Space): driven strictly by 3D camera view direction & WASD
	if jump_pressed and (attached or coyote_timer > 0.0) and jump_cooldown <= 0.0:
		var cam_3d_forward := -camera_pivot.global_basis.z
		var cam_3d_right := camera_pivot.global_basis.x
		var jump_dir := cam_3d_forward
		if not input_vector.is_zero_approx():
			var input_cam_dir := (cam_3d_right * input_vector.x + cam_3d_forward * input_vector.y).normalized()
			if not input_cam_dir.is_zero_approx():
				jump_dir = input_cam_dir

		# Surface-dependent jump deflection:
		# - Ceilings: jump forward along camera view; only clamp if aiming directly into ceiling geometry
		# - Walls: push outward away from the wall into the room if looking along/into wall
		# - Floors: ensure upward launch arc if aiming horizontal
		var is_ceiling := surface_up.dot(Vector3.DOWN) > 0.7
		var is_floor := surface_up.dot(Vector3.UP) > 0.7
		if is_ceiling:
			if jump_dir.y > -0.05:
				jump_dir.y = -0.05
				jump_dir = jump_dir.normalized()
		elif is_floor:
			if jump_dir.dot(surface_up) < 0.3:
				jump_dir = (jump_dir.slide(surface_up).normalized() * 0.6 + surface_up * 0.8).normalized()
		else:
			# Wall: ensure outward launch away from wall
			if jump_dir.dot(surface_up) < 0.2:
				jump_dir = (jump_dir.slide(surface_up).normalized() * 0.4 + surface_up * 0.85).normalized()

		var inherited_tangent := body.velocity.slide(surface_up) * 0.5
		body.velocity = inherited_tangent + jump_dir * jump_impulse
		if jump_forward_impulse > 0.0:
			var forward_bias := surface_forward.slide(surface_up).normalized()
			body.velocity += forward_bias * jump_forward_impulse
		attached = false
		is_airborne = true
		coyote_timer = 0.0
		jump_cooldown = jump_recontact_delay
		jump_launch_timer = 0.04

	# 4. Surface search and adherence
	if not is_airborne and jump_cooldown <= 0.0:
		var contact := _find_surface(desired)
		if not contact.is_empty():
			attached = true
			coyote_timer = coyote_time
			var new_normal: Vector3 = contact.normal.normalized()
			if contact.get("is_wrap", false):
				_apply_surface_transition(new_normal, true, contact.get("position", Vector3.ZERO))
			elif contact.get("transitioned", false):
				_apply_surface_transition(new_normal, false)
		else:
			attached = false
			is_airborne = true
	elif is_airborne:
		attached = false

	# 5. Camera visual smoothing & Orientation update
	if camera_pivot != null and not camera_smoothing_offset.is_zero_approx():
		camera_smoothing_offset = camera_smoothing_offset.move_toward(Vector3.ZERO, 12.0 * delta)
		camera_pivot.position = CAMERA_BASE_POS - camera_smoothing_offset
	_update_orientation(delta)

	# 6. Velocity computation & motion
	var speed := (sneak_speed if sneaking else run_speed) * movement_multiplier
	if attached:
		var tangent_velocity := body.velocity.slide(surface_up)
		tangent_velocity = tangent_velocity.move_toward(desired * speed, acceleration * delta)
		var normal_velocity := -surface_up * stick_velocity
		body.velocity = tangent_velocity + normal_velocity
		body.up_direction = surface_up
		body.floor_snap_length = floor_snap_length
		body.move_and_slide()
	else:
		# Airborne: apply air steering relative to camera view and gravity
		var air_horiz := body.velocity.slide(Vector3.UP)
		var air_forward := (-camera_pivot.global_basis.z).slide(Vector3.UP).normalized()
		if air_forward.is_zero_approx():
			air_forward = surface_forward.slide(Vector3.UP).normalized()
		var air_right := air_forward.cross(Vector3.UP).normalized()
		var air_desired := (air_right * input_vector.x + air_forward * input_vector.y).normalized()
		if not air_desired.is_zero_approx():
			air_horiz = air_horiz.move_toward(air_desired * air_max_speed, air_acceleration * delta)
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
		var hit_norm: Vector3 = down_hit.normal.normalized()
		if hit_norm.dot(surface_up) < 0.98 and transition_cooldown <= 0.0:
			down_hit["transitioned"] = true
		else:
			down_hit["transitioned"] = false
		down_hit["is_wrap"] = false
		return down_hit

	# 1b. While wrapping around an outer corner, check diagonal probe toward the corner
	if wrap_protection_timer > 0.0:
		var corner_diag := (-previous_surface_up - surface_up).normalized()
		var diag_query := PhysicsRayQueryParameters3D.create(origin, origin + corner_diag * probe_length, 1)
		diag_query.exclude = [body]
		var diag_hit := space.intersect_ray(diag_query)
		if not diag_hit.is_empty():
			diag_hit["transitioned"] = false
			diag_hit["is_wrap"] = false
			return diag_hit

	# 2. Forward-down angled probe (catches slopes and small drops ahead)
	var probe_dir := desired if not desired.is_zero_approx() else surface_forward
	var forward_down_target := origin + probe_dir * forward_probe_distance - surface_up * probe_length
	var forward_down_query := PhysicsRayQueryParameters3D.create(origin, forward_down_target, 1)
	forward_down_query.exclude = [body]
	var forward_down_hit := space.intersect_ray(forward_down_query)
	if not forward_down_hit.is_empty():
		var hit_norm: Vector3 = forward_down_hit.normal.normalized()
		if hit_norm.dot(surface_up) < 0.98 and transition_cooldown <= 0.0:
			forward_down_hit["transitioned"] = true
		else:
			forward_down_hit["transitioned"] = false
		forward_down_hit["is_wrap"] = false
		return forward_down_hit

	# 3. Outer (convex) corner wrap probe:
	# Triggers when stepping off an edge into open space (both down probes missed)
	var lateral := probe_dir.cross(surface_up).normalized()
	var lateral_offsets: Array[float] = [0.0, -wrap_lateral_offset, wrap_lateral_offset]
	for lateral_offset: float in lateral_offsets:
		var wrap_start: Vector3 = origin + probe_dir * wrap_forward_offset - surface_up * wrap_down_offset + lateral * lateral_offset
		var wrap_target: Vector3 = wrap_start - probe_dir * wrap_back_distance
		var wrap_query := PhysicsRayQueryParameters3D.create(wrap_start, wrap_target, 1)
		wrap_query.exclude = [body]
		var wrap_hit := space.intersect_ray(wrap_query)
		if not wrap_hit.is_empty():
			var hit_norm: Vector3 = wrap_hit.normal.normalized()
			if hit_norm.dot(surface_up) < surface_normal_threshold:
				wrap_hit["transitioned"] = true
				wrap_hit["is_wrap"] = true
				return wrap_hit

	return {}

func _adopt_slide_surface(desired: Vector3) -> void:
	if transition_cooldown > 0.0:
		return

	var cam_look := -camera_pivot.global_basis.z
	var best_normal := Vector3.ZERO
	var strongest_opposition := 0.0
	for index in body.get_slide_collision_count():
		var collision := body.get_slide_collision(index)
		var normal := collision.get_normal().normalized()
		if normal.dot(surface_up) > surface_normal_threshold:
			continue

		# 1. Protect against immediately bouncing back across a convex corner that was just wrapped
		if wrap_protection_timer > 0.0 and normal.dot(previous_surface_up) > 0.6:
			continue

		# Calculate opposition from movement, facing, or velocity
		var move_opposition := -desired.dot(normal) if not desired.is_zero_approx() else 0.0
		var look_opposition := -cam_look.dot(normal)
		var vel_horiz := body.velocity.slide(surface_up)
		var vel_opposition := -vel_horiz.normalized().dot(normal) if vel_horiz.length_squared() > 0.5 else 0.0

		var opposition := 0.0
		if not desired.is_zero_approx():
			# While moving: adopt if moving into wall or facing wall while moving toward it
			var intentional_push := move_opposition > 0.15 or (look_opposition > 0.25 and move_opposition > 0.05)
			if not intentional_push:
				continue
			opposition = maxf(move_opposition, look_opposition * 0.8)
		else:
			# When stationary or coasting: latch if facing wall or sliding into it
			if look_opposition < 0.4 and vel_opposition < 0.3:
				continue
			opposition = maxf(look_opposition * 0.8, vel_opposition * 0.8)

		# 2. Anti-spin in inner corners: reject cycling back to recently visited surfaces unless firmly pushed into
		var in_recent := false
		for hist_norm in recent_surface_history:
			if normal.dot(hist_norm) > surface_normal_threshold:
				in_recent = true
				break
		if in_recent and opposition < 0.4:
			continue

		# 3. Anti-jitter in corners/vents: don't immediately flip back to previous surface unless moving firmly into it
		if normal.dot(previous_surface_up) > surface_normal_threshold and opposition < 0.4:
			continue

		if opposition > strongest_opposition:
			strongest_opposition = opposition
			best_normal = normal

	if best_normal.is_zero_approx():
		return

	_apply_surface_transition(best_normal, false)
	body.velocity = body.velocity.slide(surface_up) - surface_up * stick_velocity

func _apply_surface_transition(new_normal: Vector3, is_wrap := false, wrap_pos := Vector3.ZERO) -> void:
	if new_normal.dot(surface_up) > surface_normal_threshold:
		return
	var old_up := surface_up
	previous_surface_up = old_up
	surface_up = new_normal
	transition_cooldown = surface_transition_delay
	if is_wrap:
		wrap_protection_timer = 0.35
		if wrap_pos != Vector3.ZERO:
			var edge_axis := old_up.cross(new_normal).normalized()
			if edge_axis.is_zero_approx():
				edge_axis = surface_forward.cross(old_up).normalized()
			var lateral_offset := (body.global_position - wrap_pos).project(edge_axis)
			var surface_anchor := wrap_pos + lateral_offset
			var target_pos := surface_anchor + new_normal * 0.36
			var delta_pos := target_pos - body.global_position
			body.global_position = target_pos
			if camera_pivot != null:
				camera_smoothing_offset = body.global_basis.inverse() * delta_pos

	# Keep history of last 2 surface normals to prevent cyclical 3-way corner spinning
	var already_in_history := false
	for hist_norm in recent_surface_history:
		if hist_norm.dot(old_up) > surface_normal_threshold:
			already_in_history = true
			break
	if not already_in_history:
		recent_surface_history.append(old_up)
		if recent_surface_history.size() > 2:
			recent_surface_history.pop_front()
	corner_dwell_timer = 0.3

	# Transform forward vector across surface transition using quaternion hinge rotation
	var q: Quaternion
	if old_up.dot(new_normal) < -0.99:
		var cam_x := camera_pivot.global_basis.x
		cam_x.y = 0.0
		var axis := cam_x.normalized() if not cam_x.is_zero_approx() else Vector3.RIGHT
		q = Quaternion(axis, PI)
	else:
		q = Quaternion(old_up, new_normal)

	var transition_forward := (q * surface_forward).slide(surface_up).normalized()
	if transition_forward.is_zero_approx():
		var base_forward := -old_up if is_wrap else old_up
		transition_forward = base_forward.slide(surface_up).normalized()
	if not transition_forward.is_zero_approx():
		surface_forward = transition_forward

	if is_wrap:
		body.velocity = transition_forward * (run_speed * 0.5) - surface_up * stick_velocity

func _check_airborne_landing(_desired: Vector3) -> void:
	# 1. Any slide collision during movement in the air automatically attaches the creature to the surface
	for index in body.get_slide_collision_count():
		var collision := body.get_slide_collision(index)
		var normal := collision.get_normal().normalized()
		_land_on_surface(normal)
		return

	# 2. Predictive landing check: if in close contact range of upcoming surface along flight direction
	var space := body.get_world_3d().direct_space_state
	var origin := body.global_position
	var vel := body.velocity
	if vel.length_squared() > 1.0:
		var flight_dir := vel.normalized()
		var landing_query := PhysicsRayQueryParameters3D.create(origin, origin + flight_dir * 0.5, 1)
		landing_query.exclude = [body]
		var landing_hit := space.intersect_ray(landing_query)
		if not landing_hit.is_empty():
			var normal: Vector3 = (landing_hit.normal as Vector3).normalized()
			if vel.dot(normal) <= 0.5:
				_land_on_surface(normal)
				return

	# 3. Short proximity ground raycast check
	var ground_query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * landing_probe_distance, 1)
	ground_query.exclude = [body]
	var ground_hit := space.intersect_ray(ground_query)
	if not ground_hit.is_empty():
		var normal: Vector3 = ground_hit.normal.normalized()
		if normal.y > floor_normal_threshold:
			_land_on_surface(normal)

func _land_on_surface(normal: Vector3) -> void:
	var old_up := surface_up
	previous_surface_up = old_up
	surface_up = normal
	is_airborne = false
	attached = true
	coyote_timer = coyote_time
	transition_cooldown = surface_transition_delay

	var q := Quaternion(old_up, normal) if old_up.dot(normal) > -0.99 else Quaternion(camera_pivot.global_basis.x, PI)
	var new_forward := (q * surface_forward).slide(surface_up).normalized()
	if new_forward.is_zero_approx():
		new_forward = (-camera_pivot.global_basis.z).slide(surface_up).normalized()
	if new_forward.is_zero_approx():
		new_forward = _perpendicular_to(surface_up)
	surface_forward = new_forward

func _update_orientation(delta: float) -> void:
	if is_airborne and jump_launch_timer <= 0.0:
		# Physical airborne orientation:
		# Proactively orient camera & body toward upcoming surface in flight/view direction,
		# strictly verifying reachable physics ballistics against gravity to avoid ceiling desync
		var space := body.get_world_3d().direct_space_state
		var origin := body.global_position
		var vel := body.velocity
		var cam_forward := -camera_pivot.global_basis.z
		var target_up := Vector3.UP
		var proximity_factor := 0.35
		var found_surface := false

		# 1. Primary probe along camera look direction (up to 3.5m)
		var look_query := PhysicsRayQueryParameters3D.create(origin, origin + cam_forward * 3.5, 1)
		look_query.exclude = [body]
		var look_hit := space.intersect_ray(look_query)

		if not look_hit.is_empty():
			var hit_norm: Vector3 = (look_hit.normal as Vector3).normalized()
			var dist: float = origin.distance_to(look_hit.position)
			if hit_norm.y < -0.5:
				# Target is a ceiling: strictly verify upward reachability against gravity
				var dist_y: float = look_hit.position.y - origin.y
				if dist_y > 0.0 and vel.y > 1.0 and vel.y >= sqrt(2.0 * gravity_strength * dist_y) * 0.75:
					target_up = hit_norm
					proximity_factor = clampf(1.0 - ((dist - 0.4) / 3.0), 0.35, 1.0)
					found_surface = true
			elif vel.dot(hit_norm) < 0.5:
				# Target is a wall or slope: adopt if moving toward it or nearly parallel
				target_up = hit_norm
				proximity_factor = clampf(1.0 - ((dist - 0.4) / 3.0), 0.35, 1.0)
				found_surface = true

		# 2. If camera look did not identify a valid surface, probe along velocity flight path
		if not found_surface and vel.length_squared() > 1.0:
			var flight_dir := vel.normalized()
			var reach_dist := clampf(vel.length() * 0.4, 0.6, 2.5)
			var flight_query := PhysicsRayQueryParameters3D.create(origin, origin + flight_dir * reach_dist, 1)
			flight_query.exclude = [body]
			var flight_hit := space.intersect_ray(flight_query)
			if not flight_hit.is_empty():
				var hit_norm: Vector3 = (flight_hit.normal as Vector3).normalized()
				var dist: float = origin.distance_to(flight_hit.position)
				if hit_norm.y < -0.5:
					var dist_y: float = flight_hit.position.y - origin.y
					if dist_y > 0.0 and vel.y > 1.0 and vel.y >= sqrt(2.0 * gravity_strength * dist_y) * 0.75:
						target_up = hit_norm
						proximity_factor = clampf(1.0 - ((dist - 0.35) / 2.0), 0.35, 1.0)
						found_surface = true
				else:
					target_up = hit_norm
					proximity_factor = clampf(1.0 - ((dist - 0.35) / 2.0), 0.35, 1.0)
					found_surface = true

		# 3. If no surface, orient upright toward floor (especially when falling)
		if not found_surface:
			var down_query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * 2.5, 1)
			down_query.exclude = [body]
			var down_hit := space.intersect_ray(down_query)
			if not down_hit.is_empty():
				target_up = (down_hit.normal as Vector3).normalized()
				var dist: float = origin.distance_to(down_hit.position)
				proximity_factor = clampf(1.0 - ((dist - 0.35) / 2.0), 0.35, 1.0)
			else:
				target_up = Vector3.UP

		# Ensure rotation to target_up is pitch-oriented around camera right axis to prevent yaw/roll flips
		var cam_right := camera_pivot.global_basis.x
		cam_right.y = 0.0
		var pitch_axis := cam_right.normalized() if not cam_right.is_zero_approx() else Vector3.RIGHT
		var rot_speed := air_orientation_speed * proximity_factor
		if surface_up.dot(target_up) < 0.0:
			var angle := surface_up.signed_angle_to(target_up, pitch_axis)
			surface_up = surface_up.rotated(pitch_axis, angle * clampf(rot_speed * delta, 0.0, 1.0)).normalized()
		else:
			surface_up = surface_up.slerp(target_up, clampf(rot_speed * delta, 0.0, 1.0)).normalized()

	var forward := surface_forward.slide(surface_up).normalized()
	if forward.is_zero_approx():
		forward = _perpendicular_to(surface_up)
	surface_forward = forward

	# Quaternion-based smooth orientation
	var target_basis := Basis.looking_at(forward, surface_up)
	var current_q := body.global_basis.orthonormalized().get_rotation_quaternion()
	var target_q := target_basis.orthonormalized().get_rotation_quaternion()
	var speed := air_orientation_speed if is_airborne else orientation_speed
	body.global_basis = Basis(current_q.slerp(target_q, clampf(speed * delta, 0.0, 1.0)).normalized()).orthonormalized()

func _perpendicular_to(normal: Vector3) -> Vector3:
	var axis := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
	return axis.slide(normal).normalized()
