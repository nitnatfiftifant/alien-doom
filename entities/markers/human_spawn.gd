@tool
class_name AlienDoomHumanSpawn
extends AlienDoomMapMarker

@export_enum("Worker", "Guard", "Engineer") var role: String = "Worker"
@export var patrol_id: String = ""
