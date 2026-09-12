class_name CreatureHud
extends CanvasLayer

@export var health: HealthComponent
@export var abilities: CreatureAbilities
@onready var health_label: Label = $Margin/VBox/Health
@onready var acid_label: Label = $Margin/VBox/Acid

func _ready() -> void:
	abilities.acid_cooldown_changed.connect(_on_acid_changed)

func _process(_delta: float) -> void:
	health_label.text = "ЖИЗНЬ: %d / %d" % [health.current_health, health.maximum_health]

func _on_acid_changed(remaining: float, _duration: float) -> void:
	acid_label.text = "КИСЛОТА: ГОТОВА" if remaining <= 0.0 else "КИСЛОТА: %.1f" % remaining

