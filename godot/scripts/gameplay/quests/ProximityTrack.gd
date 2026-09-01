class_name ProximityTrack
extends RefCounted
## Typed replacement for the old `{"tier": String, "dist": float}` Dictionary
## LevelRuntime._compute_tracks() put in its quest_id-keyed result map.
## The outer map (quest_id -> ProximityTrack) stays a plain Dictionary — that
## part is a genuine keyed collection, not a fixed-shape record, so typing
## it would just be ceremony.

var tier: String
var dist: float
## rpg.md section 11 backlog ("Mapa/wskaźnik celu questa") — normalized
## player-to-target vector, added alongside tier/dist (both already computed
## from the same two positions in LevelRuntime._compute_tracks(), direction
## is nearly free there) so HUD.gd's compass arrow doesn't need its own path
## back to object positions (rule 6 — UI stays decoupled from gameplay,
## same reasoning that keeps tier/dist here instead of raw positions).
var direction: Vector2

func _init(p_tier: String = "", p_dist: float = 0.0, p_direction: Vector2 = Vector2.ZERO) -> void:
	tier = p_tier
	dist = p_dist
	direction = p_direction
