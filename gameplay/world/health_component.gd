class_name HealthComponent
extends Node

signal damaged(amount: float, instigator: Node)
signal died(instigator: Node)

@export var maximum_health := 100.0
@export var current_health := 100.0

func configure(new_maximum_health: float, restore_health := true) -> void:
	maximum_health = maxf(new_maximum_health, 1.0)
	if restore_health:
		current_health = maximum_health

func apply_damage(amount: float, instigator: Node = null) -> void:
	if amount <= 0.0 or current_health <= 0.0:
		return
	current_health = maxf(0.0, current_health - amount)
	damaged.emit(amount, instigator)
	if is_zero_approx(current_health):
		died.emit(instigator)

func heal(amount: float) -> void:
	current_health = minf(maximum_health, current_health + maxf(amount, 0.0))

func restore() -> void:
	current_health = maximum_health
