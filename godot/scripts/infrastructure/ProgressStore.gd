extends Node
## Autoload singleton — Godot's equivalent of the persisted slice of
## src/store/gameStore.ts (zustand `persist`). Cross-scene progress that
## must survive a level switch (LevelRuntime instances are torn down and
## rebuilt per level, same as Phaser's Game instance) and a full app
## restart. Used sparingly as an autoload per god/godot2.md — this is
## genuinely global, persisted, cross-scene state, the same category as the
## TS store, not a convenience global.
##
## Ported subset: unlocked_levels, level_progress (completed +
## items_collected), talked_npcs, best_level_times. NOT ported yet (needs
## systems not migrated — MIGRATION_MATRIX.md): energy/difficulty-aware
## `SaveSlot` (mid-level resume position), controls/settings, volume,
## totalHops/totalDistanceWalked, dailyHistory, zenMode (session-only in TS
## too, doesn't need persistence), tutorialStage.

const SAVE_PATH := "user://progress.json"

## "Principal lead" review (plan31-08.md, point 6): the save format was a
## flat JSON object with no version field. Added now, while there's still
## only one shape to version from — cheap today, much more expensive to
## retrofit once a real migration (e.g. `SaveSlot` adding a mid-level resume
## position) actually needs to distinguish "old save, needs migrating" from
## "new save, load as-is". `load_progress()` treats a missing
## `schema_version` (any save written before this change) as version 1, the
## same shape this file already saved — no migration needed yet, but the
## branch point now exists for the first time a real shape change does.
const SCHEMA_VERSION := 1

var unlocked_levels: Array[String] = ["1"]
## level_id -> { "completed": bool, "items_collected": Array[String] }
var level_progress: Dictionary = {}
## level_id -> Array[String] of npc obj_ids talked to
var talked_npcs: Dictionary = {}
## level_id -> best completion time in ms
var best_level_times: Dictionary = {}

func _ready() -> void:
	load_progress()

func items_collected_for(level_id: String) -> Array[String]:
	var entry: Dictionary = level_progress.get(level_id, {})
	var items: Array = entry.get("items_collected", [])
	var typed: Array[String] = []
	typed.assign(items)
	return typed

func talked_for(level_id: String) -> Array[String]:
	var talked: Array = talked_npcs.get(level_id, [])
	var typed: Array[String] = []
	typed.assign(talked)
	return typed

func is_completed(level_id: String) -> bool:
	var entry: Dictionary = level_progress.get(level_id, {})
	return entry.get("completed", false)

func is_unlocked(level_id: String) -> bool:
	return unlocked_levels.has(level_id)

## Mirrors gameStore.pickUp: idempotent per obj_id, autosaves immediately
## (every zustand `set()` in the TS store synchronously persists too).
func record_item_collected(level_id: String, obj_id: String) -> void:
	var entry: Dictionary = level_progress.get(level_id, {"completed": false, "items_collected": []})
	if entry.items_collected.has(obj_id):
		return
	entry.items_collected.append(obj_id)
	level_progress[level_id] = entry
	save_progress()

## Mirrors gameStore.markTalked.
func record_talked(level_id: String, obj_id: String) -> void:
	var talked: Array = talked_npcs.get(level_id, [])
	if talked.has(obj_id):
		return
	talked.append(obj_id)
	talked_npcs[level_id] = talked
	save_progress()

## Mirrors gameStore.completeLevel: marks completed, unlocks next_level_id,
## records best time if `elapsed_ms` beats the previous one.
func record_level_completed(level_id: String, next_level_id: String, elapsed_ms: int) -> void:
	var entry: Dictionary = level_progress.get(level_id, {"completed": false, "items_collected": []})
	entry.completed = true
	level_progress[level_id] = entry

	if next_level_id != "" and not unlocked_levels.has(next_level_id):
		unlocked_levels.append(next_level_id)

	var prev_best = best_level_times.get(level_id)
	if prev_best == null or elapsed_ms < prev_best:
		best_level_times[level_id] = elapsed_ms

	save_progress()

## Autosave fires on every single collected item/talked NPC/goal — see
## AtomicSave.gd for why the write has to be atomic (.tmp + rename) rather
## than a direct in-place write.
func save_progress() -> void:
	AtomicSave.write_json(SAVE_PATH, {
		"schema_version": SCHEMA_VERSION,
		"unlocked_levels": unlocked_levels,
		"level_progress": level_progress,
		"talked_npcs": talked_npcs,
		"best_level_times": best_level_times,
	})

func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		# Timestamped explicitly (not just relying on the engine log's own
		# per-session header) — a corrupted/truncated save falling back to
		# defaults is exactly the kind of silent data loss Część 16's crash
		# logger exists to make traceable after the fact.
		push_warning("[%s] ProgressStore: %s did not contain a JSON object, ignoring" % [Time.get_datetime_string_from_system(), SAVE_PATH])
		return

	# Missing schema_version means "written before this field existed" —
	# treat as version 1 (the only shape that ever existed until now), not
	# an error. A future version bump adds an `if loaded_version < N:
	# migrate(parsed)` branch here rather than changing the fields read
	# below in place.
	var loaded_version: int = parsed.get("schema_version", 1)
	if loaded_version > SCHEMA_VERSION:
		push_warning("[%s] ProgressStore: save schema_version %d is newer than this build supports (%d) — loading anyway, some fields may be ignored" % [Time.get_datetime_string_from_system(), loaded_version, SCHEMA_VERSION])

	var loaded_unlocked: Array[String] = []
	for id in parsed.get("unlocked_levels", ["1"]):
		loaded_unlocked.append(str(id))
	unlocked_levels = loaded_unlocked if loaded_unlocked.size() > 0 else ["1"]
	level_progress = parsed.get("level_progress", {})
	talked_npcs = parsed.get("talked_npcs", {})
	best_level_times = parsed.get("best_level_times", {})

## Wipes all progress on disk and in memory — no UI hooks up to this yet
## (matches gameStore.resetProgress not being reachable without the
## Settings/menu UI it lives behind in the TS app).
func reset_progress() -> void:
	unlocked_levels = ["1"]
	level_progress = {}
	talked_npcs = {}
	best_level_times = {}
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
