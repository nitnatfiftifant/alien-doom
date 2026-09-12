class_name PauseMenu
extends CanvasLayer

@export var creature: CreatureController
@export_group("Mouse sensitivity")
@export var minimum_sensitivity := 0.0005
@export var maximum_sensitivity := 0.01
@export var sensitivity_step := 0.0001
@export var settings_path := "user://settings.cfg"
@export var settings_section := "controls"
@export var sensitivity_key := "mouse_sensitivity"

@onready var overlay: Control = $Overlay
@onready var slider: HSlider = $Overlay/Center/Panel/Margin/Content/SensitivitySlider
@onready var value_label: Label = $Overlay/Center/Panel/Margin/Content/SensitivityValue
@onready var resume_button: Button = $Overlay/Center/Panel/Margin/Content/ResumeButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	slider.min_value = minimum_sensitivity
	slider.max_value = maximum_sensitivity
	slider.step = sensitivity_step
	_load_settings()
	slider.value_changed.connect(_on_sensitivity_changed)
	resume_button.pressed.connect(resume)
	overlay.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		if get_tree().paused: resume()
		else: pause()
		get_viewport().set_input_as_handled()

func pause() -> void:
	overlay.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	resume_button.grab_focus()

func resume() -> void:
	overlay.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_sensitivity_changed(value: float) -> void:
	if creature != null: creature.mouse_sensitivity = value
	value_label.text = "%.4f" % value
	var file := ConfigFile.new()
	file.load(settings_path)
	file.set_value(settings_section, sensitivity_key, value)
	var error := file.save(settings_path)
	if error != OK: push_warning("Could not save mouse sensitivity: %s" % error_string(error))

func _load_settings() -> void:
	var fallback := creature.mouse_sensitivity if creature != null else 0.0025
	var file := ConfigFile.new()
	var value := fallback
	if file.load(settings_path) == OK:
		value = float(file.get_value(settings_section, sensitivity_key, fallback))
	value = clampf(value, minimum_sensitivity, maximum_sensitivity)
	slider.value = value
	if creature != null: creature.mouse_sensitivity = value
	value_label.text = "%.4f" % value
