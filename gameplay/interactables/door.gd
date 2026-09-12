@tool
class_name GameplayDoor
extends AnimatableBody3D

@export var automatic := false
@export var open_angle := 90.0
@export var open_speed := 5.0
var closed_rotation := 0.0
var target_rotation := 0.0

func _ready() -> void:
	closed_rotation = rotation.y
	target_rotation = closed_rotation

func interact(actor: Node3D) -> void:
	if actor is HumanController or automatic:
		var side := signf(to_local(actor.global_position).x)
		if is_zero_approx(side): side = 1.0
		target_rotation = closed_rotation + deg_to_rad(open_angle) * -side

func close() -> void:
	target_rotation = closed_rotation

func _physics_process(delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, target_rotation, clampf(open_speed * delta, 0.0, 1.0))

