class_name HumanCautiousState
extends HumanState

func enter() -> void:
	transition_substate(&"Investigate")
