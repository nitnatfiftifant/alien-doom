class_name SurfaceSensorDebugPanel
extends Control

@export var motor: SurfaceMotor
@export var contact_resolver: Node
@export var view_camera: Camera3D
@export var adhesion_probe: RayCast3D
@export var initially_visible := false
@export var toggle_key := KEY_F3
@export_range(60.0, 180.0, 1.0) var diagram_radius := 105.0
@export var hit_color := Color(0.25, 1.0, 0.38, 1.0)
@export var miss_color := Color(0.42, 0.46, 0.52, 0.75)
@export var selected_color := Color(1.0, 0.78, 0.12, 1.0)
@export var body_contact_color := Color(1.0, 0.35, 0.22, 1.0)

@onready var details: Label = $Details
var _samples: Array[Dictionary] = []

func _ready() -> void:
	visible = initially_visible
	set_process(visible)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == toggle_key:
		visible = not visible
		set_process(visible)
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	_collect_samples()
	details.text = _build_details()
	queue_redraw()

func get_samples() -> Array[Dictionary]:
	return _samples.duplicate(true)

func _collect_samples() -> void:
	_samples.clear()
	if motor != null:
		_samples.append_array(motor.get_debug_probe_samples())
	if contact_resolver != null and motor != null:
		# The virtual legs are normally queried only when the direct probes miss.
		# While this panel is open, sample them every frame so the whole sensor rig
		# remains observable without changing movement decisions.
		contact_resolver.call(&"sample_support", motor.surface_up, motor.surface_forward, Vector3.ZERO)
		_samples.append_array(contact_resolver.call(&"get_probe_samples"))
	_append_adhesion_probe()

func _append_adhesion_probe() -> void:
	if adhesion_probe == null:
		return
	adhesion_probe.force_raycast_update()
	var target := adhesion_probe.to_global(adhesion_probe.target_position)
	var colliding := adhesion_probe.is_colliding()
	_samples.append({
		"name": "adhesion_raycast",
		"category": "adhesion",
		"start": adhesion_probe.global_position,
		"end": target,
		"hit": colliding,
		"position": adhesion_probe.get_collision_point() if colliding else target,
		"normal": adhesion_probe.get_collision_normal() if colliding else Vector3.ZERO,
		"collider": adhesion_probe.get_collider() if colliding else null,
		"selected": false,
	})

func _draw() -> void:
	var box := Rect2(Vector2.ZERO, size)
	draw_rect(box, Color(0.025, 0.035, 0.055, 0.9), true)
	draw_rect(box, Color(0.28, 0.75, 0.85, 0.75), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(16, 25), "ДАТЧИКИ ПОВЕРХНОСТИ  [F3]", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	var center := Vector2(minf(145.0, size.x * 0.32), 158.0)
	draw_circle(center, 20.0, Color(0.46, 0.08, 0.1, 0.95))
	draw_circle(center, 20.0, Color.WHITE, false, 2.0)
	for sample in _samples:
		_draw_sample(sample, center)
	draw_string(ThemeDB.fallback_font, Vector2(16, 292), "зелёный: контакт   серый: промах   жёлтый: опора", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.85, 0.9))

func _draw_sample(sample: Dictionary, center: Vector2) -> void:
	if view_camera == null:
		return
	var start: Vector3 = sample.get("start", Vector3.ZERO)
	var end: Vector3 = sample.get("position", sample.get("end", start))
	var direction := end - start
	if direction.is_zero_approx():
		return
	direction = direction.normalized()
	var screen_direction := Vector2(direction.dot(view_camera.global_basis.x), -direction.dot(view_camera.global_basis.y))
	if screen_direction.length_squared() < 0.0025:
		screen_direction = Vector2(0.0, -1.0 if direction.dot(-view_camera.global_basis.z) >= 0.0 else 1.0)
	else:
		screen_direction = screen_direction.normalized()
	var color := _sample_color(sample)
	var endpoint := center + screen_direction * diagram_radius
	draw_line(center, endpoint, color, 2.5, true)
	draw_circle(endpoint, 5.0, color)
	var short_name := String(sample.get("name", "?"))
	draw_string(ThemeDB.fallback_font, endpoint + Vector2(7, 4), short_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)

func _sample_color(sample: Dictionary) -> Color:
	if bool(sample.get("selected", false)):
		return selected_color
	if not bool(sample.get("hit", false)):
		return miss_color
	if String(sample.get("category", "")) == "body":
		return body_contact_color
	return hit_color

func _build_details() -> String:
	var state_line := "МОТОР: не подключён"
	if motor != null:
		state_line = "МОТОР: %s  up(%.2f, %.2f, %.2f)" % ["НА ПОВЕРХНОСТИ" if motor.attached else "В ВОЗДУХЕ", motor.surface_up.x, motor.surface_up.y, motor.surface_up.z]
	var lines := PackedStringArray([state_line, "ПОПАДАНИЯ:"])
	if motor != null and motor.frame_resolver != null:
		var target: Vector3 = motor.frame_resolver.target_normal
		lines.insert(1, "FRAME: %s  уверенность %.2f target(%.2f, %.2f, %.2f)" % [motor.frame_resolver.primary_source, motor.frame_resolver.confidence, target.x, target.y, target.z])
	var hit_count := 0
	for sample in _samples:
		if not bool(sample.get("hit", false)):
			continue
		hit_count += 1
		var collider: Object = sample.get("collider", null)
		var collider_name := "<нет>"
		if is_instance_valid(collider):
			collider_name = collider.name if collider is Node else collider.get_class()
		var normal: Vector3 = sample.get("normal", Vector3.ZERO)
		lines.append("%s → %s  n(%.2f, %.2f, %.2f)" % [sample.get("name", "?"), collider_name, normal.x, normal.y, normal.z])
	if hit_count == 0:
		lines.append("нет контактов")
	lines.append("\nВсего: %d, активны: %d" % [_samples.size(), hit_count])
	return "\n".join(lines)
