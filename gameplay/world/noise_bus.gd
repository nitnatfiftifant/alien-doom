class_name NoiseBus
extends Node

signal noise_emitted(position: Vector3, loudness: float, source: Node)

func emit_noise(position: Vector3, loudness: float, source: Node) -> void:
	noise_emitted.emit(position, maxf(loudness, 0.0), source)

