class_name NoiseBus
extends Node

signal noise_emitted(position: Vector3, loudness: float, source: Node)
signal alarm_emitted(position: Vector3, loudness: float, source: Node, threat_position: Vector3)

func emit_noise(position: Vector3, loudness: float, source: Node) -> void:
	noise_emitted.emit(position, maxf(loudness, 0.0), source)

func emit_alarm(position: Vector3, loudness: float, source: Node, threat_position: Vector3) -> void:
	alarm_emitted.emit(position, maxf(loudness, 0.0), source, threat_position)
