class_name HumanState
extends Node

@export var state_id: StressComponent.State
var actor: HumanController

func setup(value: HumanController) -> void:
	actor = value

func enter() -> void:
	pass

func exit() -> void:
	pass

func physics_update(_delta: float) -> void:
	pass

