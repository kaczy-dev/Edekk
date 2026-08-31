class_name QuestStatus
extends RefCounted
## Typed replacement for the old `{"quest":..., "done":..., ...}` Dictionary
## QuestUtils.compute_quests() used to return one of per quest. Same
## "transient computed value" reasoning as before, but plain-typed fields
## remove the string-keyed-lookup typo risk the previous docstring called
## out as a known tradeoff. See docs/migration/MIGRATION_MATRIX.md, Sprint 1.

var quest: QuestStepData
var done: bool = false
var current: int = 0
var total: int = 0
## Only meaningful for "reach" quests — true once all `requires` are met but
## the player hasn't walked into the goal area yet. Defaults false for
## "collect"/"talk" quests, same as when the key was simply absent from the
## old Dictionary (HUD.gd used `status.get("ready", false)`).
var ready: bool = false
var missing: Array[MissingHint] = []

func _init(p_quest: QuestStepData = null) -> void:
	quest = p_quest
