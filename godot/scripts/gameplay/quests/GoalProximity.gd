class_name GoalProximity
extends RefCounted
## Ported 1:1 from src/game/proximity.ts. Pure logic, no Node dependency —
## engine-agnostic in the TS source too. Static-only.
##
## NOT ported: the on-canvas arrow/glyph/colour-blind styling from
## tierStyle.ts and the smoothing/tick-loop from goalTracking.ts (React
## `requestAnimationFrame` state) — HUD.gd shows tier + distance as plain
## text instead (LevelRuntime._process() recomputes per-frame, no smoothing
## yet). See MIGRATION_MATRIX.md, "Proximity/goal hints".

const GOAL_PROXIMITY := {
	"gate": {"label": "Brama / drzwi", "size_factor": 1.15, "slack": 46.0, "min": 70.0, "max": 240.0, "near_factor": 2.2, "mid_factor": 5.0},
	"chest": {"label": "Skrzynia", "size_factor": 0.95, "slack": 26.0, "min": 48.0, "max": 150.0, "near_factor": 2.4, "mid_factor": 5.5},
	"food": {"label": "Szynka / jedzenie", "size_factor": 0.85, "slack": 18.0, "min": 38.0, "max": 120.0, "near_factor": 2.6, "mid_factor": 6.0},
	"spot": {"label": "Miejsce", "size_factor": 1.0, "slack": 28.0, "min": 48.0, "max": 180.0, "near_factor": 2.2, "mid_factor": 5.0},
}

const FOOD_ITEMS := [&"treat", &"bowl", &"mouse"]
const GATE_WORDS := ["gate", "brama", "door", "drzwi", "exit", "hatch", "luk", "roof"]
const CHEST_WORDS := ["chest", "skrzynia", "skrzyn", "box", "kufer"]
const FOOD_WORDS := ["ham", "szynka", "szynk", "food", "jedzenie", "jedzen", "bowl", "miska", "treat"]

static func _id_words(id: String) -> PackedStringArray:
	var regex := RegEx.new()
	regex.compile("[^a-zA-Ząćęłńóśźż]+")
	return regex.sub(id.to_lower(), " ", true).split(" ", false)

## Classify a level object into a proximity archetype ("gate"|"chest"|"food"|"spot").
static func goal_archetype(obj: LevelObjectData) -> String:
	var words := _id_words(obj.id)
	for w in words:
		if GATE_WORDS.has(w):
			return "gate"
	for w in words:
		if CHEST_WORDS.has(w):
			return "chest"
	for w in words:
		if FOOD_WORDS.has(w):
			return "food"
	if obj.item_id != &"" and FOOD_ITEMS.has(obj.item_id):
		return "food"
	if obj.item_id == &"chest":
		return "chest"
	return "spot"

## Returns radii in world px. Typed ProximityInfo instead of a Dictionary
## literal — see docs/migration/MIGRATION_MATRIX.md, Sprint 1 refactor note.
static func goal_proximity(obj: LevelObjectData, scale: float = 1.0) -> ProximityInfo:
	var archetype := goal_archetype(obj)
	var profile: Dictionary = GOAL_PROXIMITY[archetype]
	var half_diag := Vector2(obj.rect.size.x, obj.rect.size.y).length() / 2.0
	var size_factor: float = profile.size_factor
	var slack: float = profile.slack
	var min_r: float = profile.min
	var max_r: float = profile.max
	var near_factor: float = profile.near_factor
	var mid_factor: float = profile.mid_factor
	var raw := half_diag * size_factor + slack
	var at := clampf(raw, min_r, max_r) * scale
	return ProximityInfo.new(archetype, profile.label, at, at * near_factor, at * mid_factor)

## dist <= at -> "at", <= near -> "near", <= mid -> "mid", else "far".
static func tier_for(dist: float, at: float, near: float, mid: float) -> String:
	if dist <= at:
		return "at"
	if dist <= near:
		return "near"
	if dist <= mid:
		return "mid"
	return "far"

const TIER_LABELS := {"at": "tuż obok", "near": "blisko", "mid": "średnio", "far": "daleko"}
