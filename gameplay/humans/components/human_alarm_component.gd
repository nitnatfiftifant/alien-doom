class_name HumanAlarmComponent
extends Node

@export var actor: HumanController
@export var indicator: Label3D
@export var voice: AudioStreamPlayer3D
@export var alarm_loudness := 1.5
@export var repeat_interval := 4.0

var confirmed_sighting := false
var alarm_cooldown := 0.0
static var warning_sound: AudioStreamWAV

func _ready() -> void:
	indicator.visible = false
	if warning_sound == null:
		warning_sound = _make_warning_sound()
	voice.stream = warning_sound

func tick(delta: float) -> void:
	if actor.is_in_group("corpses"):
		stop()
		return
	alarm_cooldown = maxf(0.0, alarm_cooldown - delta)
	if actor.stress.state == StressComponent.State.CALM:
		confirmed_sighting = false
		alarm_cooldown = 0.0
		indicator.visible = false
		return
	if actor.awareness.creature_visible and actor.stress.state == StressComponent.State.ALERT:
		confirmed_sighting = true
		if alarm_cooldown <= 0.0:
			alarm_cooldown = repeat_interval
			(get_node("/root/NOISE") as NoiseBus).emit_alarm(actor.perception.global_position, alarm_loudness, actor, actor.awareness.last_known_position)
			voice.play()
	refresh_indicator(actor.stress.state)

func refresh_indicator(state: StressComponent.State) -> void:
	# Display what the NPC knows, including alarm received from another human.
	# Personal visual contact is only relevant to emitting a new audible warning.
	indicator.visible = state != StressComponent.State.CALM and not actor.is_in_group("corpses")
	indicator.text = "?" if state == StressComponent.State.CAUTIOUS else "!"
	indicator.modulate = Color(1.0, 0.85, 0.12)
	if state == StressComponent.State.POST_ALERT:
		indicator.modulate = Color(1.0, 0.4, 0.05)
	elif state == StressComponent.State.ALERT:
		indicator.modulate = Color(1.0, 0.15, 0.07)

func stop() -> void:
	indicator.visible = false
	voice.stop()
	confirmed_sighting = false
	alarm_cooldown = 0.0

func _make_warning_sound() -> AudioStreamWAV:
	# A short two-tone warning; generated once and shared by all humans.
	var sample_rate := 22050
	var count := int(sample_rate * 0.36)
	var samples := PackedByteArray()
	samples.resize(count * 2)
	for index in count:
		var time := float(index) / sample_rate
		var local_time := fmod(time, 0.18)
		var envelope := minf(local_time / 0.015, 1.0) * clampf((0.14 - local_time) / 0.035, 0.0, 1.0)
		var frequency := 760.0 if time < 0.18 else 1040.0
		samples.encode_s16(index * 2, int(sin(TAU * frequency * time) * envelope * 10000.0))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = sample_rate
	sound.data = samples
	return sound
