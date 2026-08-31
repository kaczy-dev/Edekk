class_name ProximityTrack
extends RefCounted
## Typed replacement for the old `{"tier": String, "dist": float}` Dictionary
## LevelRuntime._compute_tracks() put in its quest_id-keyed result map.
## The outer map (quest_id -> ProximityTrack) stays a plain Dictionary — that
## part is a genuine keyed collection, not a fixed-shape record, so typing
## it would just be ceremony.

var tier: String
var dist: float

func _init(p_tier: String = "", p_dist: float = 0.0) -> void:
	tier = p_tier
	dist = p_dist
