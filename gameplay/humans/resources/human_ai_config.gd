class_name HumanAIConfig
extends Resource

@export_group("Locomotion")
@export_range(0.5, 10.0, 0.1, "or_greater") var move_speed := 3.2
@export_range(0.1, 20.0, 0.1, "or_greater") var acceleration := 10.0
@export_range(0.1, 20.0, 0.1, "or_greater") var turn_speed := 8.0
@export_range(0.05, 2.0, 0.05, "or_greater") var arrival_distance := 0.65

@export_group("Investigate")
@export_range(0.1, 10.0, 0.1, "or_greater") var investigate_wait_seconds := 2.0

@export_group("Search")
@export_range(0.5, 60.0, 0.5, "or_greater") var search_duration := 8.0
@export_range(0.1, 10.0, 0.1, "or_greater") var search_radius := 4.0
@export_range(0.1, 10.0, 0.1, "or_greater") var search_retarget_seconds := 1.5
@export_range(0.1, 6.0, 0.1, "or_greater") var search_turn_speed := 1.8

@export_group("Flee")
@export_range(1.0, 30.0, 0.5, "or_greater") var flee_distance := 10.0
@export_range(0.1, 5.0, 0.1, "or_greater") var flee_repath_seconds := 0.5

@export_group("Awareness")
@export_range(0.1, 30.0, 0.1, "or_greater") var stress_share_radius := 8.0

