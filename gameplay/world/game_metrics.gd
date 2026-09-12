class_name GameMetrics
extends RefCounted

const TRENCHBROOM_UNITS_PER_METER := 32.0
const HUMAN_SIZE_UNITS := Vector3(32, 72, 32)
const CREATURE_SIZE_UNITS := Vector3(24, 20, 24)
const MINIMUM_VENT_SIZE_UNITS := Vector2(32, 32)

static func units_to_meters(value: float) -> float:
	return value / TRENCHBROOM_UNITS_PER_METER

