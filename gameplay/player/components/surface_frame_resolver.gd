class_name SurfaceFrameResolver
extends Node

@export_group("Response")
@export_range(1.0, 40.0, 0.5) var normal_response_speed := 12.0
@export_range(1.0, 40.0, 0.5) var target_response_speed := 8.0
@export_range(0.0, 1.0, 0.01) var same_surface_dot := 0.96
@export_range(-1.0, 1.0, 0.01) var compatible_normal_dot := -0.05
@export_range(0.8, 0.999, 0.001) var normal_cluster_dot := 0.98
@export_range(0.25, 2.5, 0.05) var contact_distance_scale := 1.2
@export_range(0.01, 1.0, 0.01) var minimum_proximity_weight := 0.12
@export_range(0.2, 2.0, 0.05) var manifold_contact_span := 0.72
@export_range(0.0, 8.0, 0.1) var physical_intent_boost := 4.0
@export_group("Candidate weights")
@export_range(0.0, 10.0, 0.1) var current_support_weight := 4.0
@export_range(0.0, 10.0, 0.1) var movement_contact_weight := 5.0
@export_range(0.0, 10.0, 0.1) var wrap_contact_weight := 3.0
@export_range(0.0, 10.0, 0.1) var body_contact_weight := 2.5
@export_range(0.0, 10.0, 0.1) var leg_contact_weight := 1.0

var target_normal := Vector3.UP
var support_normal := Vector3.UP
var support_point := Vector3.ZERO
var confidence := 0.0
var primary_source := "none"

func reset(normal := Vector3.UP) -> void:
	target_normal = normal.normalized()
	support_normal = target_normal
	support_point = Vector3.ZERO
	confidence = 0.0
	primary_source = "none"

func resolve(current_normal: Vector3, desired: Vector3, origin: Vector3, candidates: Array[Dictionary], delta: float) -> Dictionary:
	# Spawns, respawns and scripted teleports may replace the motor frame without
	# going through this resolver. Discard incompatible temporal history.
	if target_normal.dot(current_normal) < 0.5:
		target_normal = current_normal.normalized()
		support_normal = target_normal

	var current_support: Array[Dictionary] = []
	var movement_contacts: Array[Dictionary] = []
	var slope_contacts: Array[Dictionary] = []
	var edge_contacts: Array[Dictionary] = []
	var wrap_contacts: Array[Dictionary] = []
	var fallback_contacts: Array[Dictionary] = []
	var physical_contacts: Array[Dictionary] = []

	var forward_down_hit := false
	var forward_down_same_plane := false

	for candidate in candidates:
		if not bool(candidate.get("hit", false)):
			continue
		var normal: Vector3 = (candidate.get("normal", Vector3.ZERO) as Vector3).normalized()
		if normal.is_zero_approx():
			continue
		var source := String(candidate.get("source", ""))
		if source == "slide":
			candidate["intent_weight"] = 1.0 + maxf(0.0, -desired.dot(normal)) * physical_intent_boost
			physical_contacts.append(candidate)
		elif source == "down":
			if normal.dot(current_normal) >= same_surface_dot:
				current_support.append(candidate)
			else:
				slope_contacts.append(candidate)
		elif source == "forward_down":
			forward_down_hit = true
			if normal.dot(current_normal) >= same_surface_dot:
				forward_down_same_plane = true
				edge_contacts.append(candidate)
			else:
				# Ground ahead is a slope, bevel or ramp!
				slope_contacts.append(candidate)
		elif source == "movement" and not desired.is_zero_approx() and -desired.dot(normal) > 0.001:
			movement_contacts.append(candidate)
		elif source == "wrap":
			wrap_contacts.append(candidate)
		elif source == "diagonal":
			edge_contacts.append(candidate)
		else:
			# Virtual legs or other sensors
			if not desired.is_zero_approx() and -desired.dot(normal) > 0.1 and normal.dot(current_normal) < same_surface_dot:
				slope_contacts.append(candidate)
			else:
				fallback_contacts.append(candidate)

	# Determine terrain condition ahead
	var on_flat_plane := not current_support.is_empty() and forward_down_hit and forward_down_same_plane
	var at_convex_edge := not forward_down_hit or current_support.is_empty()

	var active: Array[Dictionary] = []
	var allow_multiple_planes := false
	if not physical_contacts.is_empty():
		# The only authoritative multi-plane manifold comes from contacts produced
		# by CharacterBody3D. A short intentional movement ray may join it only to
		# initiate contact with the face the sphere is currently pushing against;
		# the forward-down probe does the same for a ramp immediately ahead.
		active.append_array(physical_contacts)
		active.append_array(movement_contacts)
		active.append_array(slope_contacts)
		allow_multiple_planes = true
	elif not movement_contacts.is_empty() or not slope_contacts.is_empty():
		# Actively pressing into a wall or moving onto a slope/ramp ahead
		active.append_array(current_support)
		active.append_array(movement_contacts)
		active.append_array(slope_contacts)
		allow_multiple_planes = true
		for c in fallback_contacts:
			if (c.get("position", origin) as Vector3).distance_to(origin) <= manifold_contact_span:
				active.append(c)
	elif at_convex_edge:
		# Convex corner / ledge: wrap contacts are essential!
		active.append_array(current_support)
		active.append_array(edge_contacts)
		active.append_array(wrap_contacts)
		active.append_array(fallback_contacts)
	elif on_flat_plane:
		# Continuous flat plane: exclude remote wrap rays to prevent corridor distortion
		active.append_array(current_support)
		for c in edge_contacts:
			if (c.get("position", origin) as Vector3).distance_to(origin) <= manifold_contact_span:
				active.append(c)
		for c in fallback_contacts:
			if (c.get("position", origin) as Vector3).distance_to(origin) <= manifold_contact_span:
				active.append(c)
	else:
		active.append_array(current_support)
		active.append_array(edge_contacts)
		active.append_array(fallback_contacts)

	if active.is_empty():
		confidence = 0.0
		primary_source = "none"
		return {}

	var manifold := _cluster_contacts(active, origin)
	manifold.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.weight) > float(b.weight))
	if not allow_multiple_planes and manifold.size() > 1:
		manifold.resize(1)
	var primary_point: Vector3 = manifold[0].position
	var local_manifold: Array[Dictionary] = []
	for cluster in manifold:
		if (cluster.position as Vector3).distance_to(primary_point) <= manifold_contact_span:
			local_manifold.append(cluster)
	manifold = local_manifold

	var reference: Vector3 = (manifold[0].normal as Vector3).normalized()
	var adhesion_reference := reference
	var is_wrap := false
	var wrap_pos := Vector3.ZERO

	if not physical_contacts.is_empty():
		# Keep the collision sphere pressed into one real face, preferably the
		# face already carrying it. The visual/movement frame may still be the
		# average of all physical contacts.
		var best_alignment := -INF
		for cluster in manifold:
			var cluster_normal: Vector3 = (cluster.normal as Vector3).normalized()
			var alignment := cluster_normal.dot(current_normal)
			if alignment > best_alignment:
				best_alignment = alignment
				adhesion_reference = cluster_normal
	elif String(manifold[0].get("source", "")) == "wrap":
		is_wrap = true
		wrap_pos = manifold[0].get("position", Vector3.ZERO)
		adhesion_reference = reference
	elif not movement_contacts.is_empty() or not slope_contacts.is_empty():
		if not desired.is_zero_approx() and -desired.dot(reference) > 0.05:
			adhesion_reference = reference
		elif not current_support.is_empty():
			adhesion_reference = (current_support[0].normal as Vector3).normalized()
	elif not current_support.is_empty():
		adhesion_reference = (current_support[0].normal as Vector3).normalized()

	var normal_sum := Vector3.ZERO
	var point_sum := Vector3.ZERO
	var weight_sum := 0.0
	var used_count := 0
	for candidate in manifold:
		var normal: Vector3 = (candidate.normal as Vector3).normalized()
		if normal.dot(reference) < compatible_normal_dot:
			continue
		var weight: float = candidate.weight
		normal_sum += normal * weight
		point_sum += (candidate.get("position", Vector3.ZERO) as Vector3) * weight
		weight_sum += weight
		used_count += 1
	if normal_sum.is_zero_approx() or weight_sum <= 0.0:
		return {}

	var measured_normal := normal_sum.normalized()
	if manifold.size() == 1:
		target_normal = measured_normal
	else:
		target_normal = _rotate_toward(target_normal, measured_normal, target_response_speed * delta)
	support_normal = _rotate_toward(current_normal, target_normal, normal_response_speed * delta)
	support_point = point_sum / weight_sum
	confidence = clampf(weight_sum / 8.0, 0.0, 1.0)
	primary_source = String(manifold[0].get("source", "unknown"))

	return {
		"normal": support_normal,
		"target_normal": target_normal,
		"adhesion_normal": adhesion_reference,
		"position": support_point,
		"confidence": confidence,
		"contact_count": used_count,
		"primary_source": primary_source,
		"is_wrap": is_wrap,
		"wrap_position": wrap_pos,
	}

func _cluster_contacts(candidates: Array[Dictionary], origin: Vector3) -> Array[Dictionary]:
	var clusters: Array[Dictionary] = []
	for candidate in candidates:
		var normal: Vector3 = (candidate.normal as Vector3).normalized()
		var distance: float = origin.distance_to(candidate.get("position", origin))
		var proximity := maxf(minimum_proximity_weight, 1.0 - clampf(distance / contact_distance_scale, 0.0, 1.0))
		var weighted_score := _weight(candidate) * proximity * float(candidate.get("intent_weight", 1.0))
		var matching_index := -1
		for cluster_index in clusters.size():
			if normal.dot(clusters[cluster_index].normal) >= normal_cluster_dot:
				matching_index = cluster_index
				break
		if matching_index < 0:
			clusters.append({
				"normal": normal,
				"position": candidate.get("position", origin),
				"weight": weighted_score,
				"source": candidate.get("source", "unknown"),
			})
		elif weighted_score > float(clusters[matching_index].weight):
			# Multiple rays hitting the same plane are one physical support, not
			# several votes. Retain only the strongest/nearest representative.
			clusters[matching_index] = {
				"normal": normal,
				"position": candidate.get("position", origin),
				"weight": weighted_score,
				"source": candidate.get("source", "unknown"),
			}
	return clusters

func _weight(candidate: Dictionary) -> float:
	match String(candidate.get("source", "")):
		"down": return current_support_weight
		"movement": return movement_contact_weight
		"wrap", "diagonal", "forward_down": return wrap_contact_weight
		"slide": return body_contact_weight
		"leg": return leg_contact_weight
	return 1.0

func _rotate_toward(from_normal: Vector3, to_normal: Vector3, max_angle: float) -> Vector3:
	var from := from_normal.normalized()
	var to := to_normal.normalized()
	var angle := from.angle_to(to)
	if angle <= max_angle or angle <= 0.00001:
		return to
	var axis := from.cross(to).normalized()
	if axis.is_zero_approx():
		axis = Vector3.RIGHT if absf(from.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
		axis = axis.slide(from).normalized()
	return from.rotated(axis, max_angle).normalized()
