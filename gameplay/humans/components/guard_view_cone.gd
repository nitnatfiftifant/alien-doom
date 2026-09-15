class_name GuardViewCone
extends MeshInstance3D

@export var actor: HumanController
@export var cone_color := Color(1.0, 0.86, 0.4, 0.12)
@export_range(12, 96, 4) var segments := 48
@export_range(0.03, 0.5, 0.01) var update_interval := 0.1

var perception: PerceptionComponent
var update_timer := 0.0

func _ready() -> void:
	perception = get_parent() as PerceptionComponent
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	process_physics_priority = 1
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = false
	material_override = material
	refresh_role()

func refresh_role() -> void:
	visible = actor.is_guard() and not actor.is_in_group("corpses")
	set_physics_process(visible)
	update_timer = 0.0

func _physics_process(delta: float) -> void:
	update_timer -= delta
	if update_timer > 0.0:
		return
	update_timer = update_interval
	rebuild_mesh()

func rebuild_mesh() -> void:
	# The visual shares the sensor's origin, forward axis, angle and range.
	# Clip sampled rays against solid geometry; this is a direction cue,
	# while PerceptionComponent remains responsible for exact visibility.
	var half_angle := deg_to_rad(clampf(perception.direct_half_angle, 0.1, 89.0))
	var distance := maxf(perception.direct_view_distance, 0.01)
	var center := _clip_ray(Vector3.FORWARD * distance)
	var rim: PackedVector3Array = []
	for index in segments:
		var angle := TAU * float(index) / float(segments)
		var direction := Vector3(sin(half_angle) * cos(angle), sin(half_angle) * sin(angle), -cos(half_angle))
		rim.append(_clip_ray(direction * minf(distance, center.length() / cos(half_angle))))
	var vertices: PackedVector3Array = []
	var colors: PackedColorArray = []
	var rim_color := Color(cone_color, cone_color.a * 0.12)
	for index in segments:
		vertices.append_array(PackedVector3Array([Vector3.ZERO, rim[index], rim[(index + 1) % segments]]))
		colors.append_array(PackedColorArray([cone_color, rim_color, rim_color]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var cone_mesh := ArrayMesh.new()
	cone_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = cone_mesh

func _clip_ray(endpoint: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(global_position, to_global(endpoint), 1 | 8)
	query.exclude = [actor.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return endpoint
	var local_hit := to_local(hit.position)
	return local_hit.normalized() * maxf(local_hit.length() - 0.03, 0.0)
