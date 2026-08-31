class_name ProximityInfo
extends RefCounted
## Typed replacement for GoalProximity.goal_proximity()'s old
## `{"archetype":..., "label":..., "at":..., "near":..., "mid":...}`
## Dictionary return — radii in world px, see GoalProximity.gd header.

var archetype: String
var label: String
var at: float
var near: float
var mid: float

func _init(p_archetype: String = "", p_label: String = "", p_at: float = 0.0, p_near: float = 0.0, p_mid: float = 0.0) -> void:
	archetype = p_archetype
	label = p_label
	at = p_at
	near = p_near
	mid = p_mid
