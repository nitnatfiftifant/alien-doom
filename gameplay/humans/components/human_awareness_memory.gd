class_name HumanAwarenessMemory
extends Node

enum StimulusKind { NONE, CREATURE, CORPSE, NOISE }

var tracked_creature: CreatureController
var creature_visible := false
var last_known_position := Vector3.ZERO
var last_stimulus_kind := StimulusKind.NONE
var seconds_since_visual := INF

func tick(delta: float) -> void:
	seconds_since_visual += delta

func track_creature(creature: CreatureController, visible: bool) -> void:
	tracked_creature = creature
	creature_visible = visible
	if creature != null and visible:
		last_known_position = creature.global_position
		last_stimulus_kind = StimulusKind.CREATURE
		seconds_since_visual = 0.0

func remember_stimulus(position: Vector3, is_corpse: bool) -> void:
	last_known_position = position
	last_stimulus_kind = StimulusKind.CORPSE if is_corpse else StimulusKind.NOISE

