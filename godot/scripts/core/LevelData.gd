class_name LevelData
extends Resource
## Ported from src/game/types.ts (LevelDef). One .tres per level lives in
## godot/data/levels/. Rendering-only fields (pointLight, layers, mood) are
## kept as loosely-typed Dictionary, same reasoning as LevelObjectData.requires
## — they're not consumed by any gameplay logic yet (Atmosfera/post-FX system,
## MIGRATION_MATRIX.md, not migrated), so a dedicated Resource class would be
## speculative right now.

@export var id: String
@export var slug: String
@export var title: String
@export var subtitle: String
@export var background: String
## Virtual world size in px.
@export var width: float
@export var height: float
@export var spawn: Vector2
@export var ambient: String = "" # "day" | "dim" | "night"
@export var ambient_fx: String = "" # "motes" | "petals" | "dust" | "stars"
@export var intro: String
@export var objective: String
@export var unlock_hint: String
@export var quests: Array[QuestStepData] = []
@export var objects: Array[LevelObjectData] = []
## { x, y, color, intensity } or empty.
@export var point_light: Dictionary = {}
## Per-level color grading (sepia, brightness, contrast, saturate, hue,
## vignetteStrength) or empty for the generic day/dim/night default.
@export var mood: Dictionary = {}
