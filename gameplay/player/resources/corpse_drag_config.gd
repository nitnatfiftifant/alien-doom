class_name CorpseDragConfig
extends Resource

@export_group("Acquisition")
@export var reach := 3.2
@export_flags_3d_physics var acquisition_mask := 9
@export var aim_radius := 0.42
@export_group("Hold distance")
@export var break_distance := 4.5
@export var minimum_hold_distance := 1.1
@export var maximum_hold_distance := 3.0
@export_group("Spring")
@export var spring_stiffness := 14.0
@export var spring_damping := 7.0
@export var maximum_acceleration := 18.0
@export_range(0.0, 1.0) var distributed_pull_ratio := 0.85
@export_range(0.0, 1.0) var held_gravity_scale := 0.35
@export_group("Player")
@export_range(0.1, 1.0) var movement_multiplier := 0.55
