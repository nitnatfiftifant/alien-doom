class_name BiteOverlay
extends AnimatedSprite2D

const FRAME_SIZE := Vector2(128.0, 128.0)

func _ready() -> void:
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_fit_to_viewport):
		viewport.size_changed.connect(_fit_to_viewport)
	call_deferred("_fit_to_viewport")
	play(&"idle")

func _exit_tree() -> void:
	var viewport := get_viewport()
	if viewport != null and viewport.size_changed.is_connected(_fit_to_viewport):
		viewport.size_changed.disconnect(_fit_to_viewport)

func play_bite() -> void:
	play(&"bite")

func _fit_to_viewport() -> void:
	if not is_inside_tree():
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var viewport_size := Vector2(viewport.get_visible_rect().size)
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	position = viewport_size * 0.5
	var cover_scale := maxf(viewport_size.x / FRAME_SIZE.x, viewport_size.y / FRAME_SIZE.y)
	scale = Vector2.ONE * cover_scale
