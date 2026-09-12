class_name CreatureCombatConfig
extends Resource

@export_group("Bite")
@export var bite_damage := 50.0
@export var bite_range := 1.7
@export var back_bite_multiplier := 1.5
@export_range(-1.0, 1.0) var back_bite_dot_threshold := -0.35

@export_group("Acid")
@export var acid_damage := 35.0
@export var acid_range := 12.0
@export var acid_cooldown := 8.0
