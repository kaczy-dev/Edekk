extends Node
## Autoload singleton — Godot's equivalent of the non-progress persisted
## slice of src/store/gameStore.ts (zustand `persist`): volume, muted,
## difficulty, and the one `ControlSettings` field with an actual gameplay
## consumer so far (`sprintMode`). Same "genuinely global, persisted,
## cross-scene state" bar as ProgressStore.gd — third autoload, still used
## sparingly (each one has a distinct, non-overlapping responsibility).
##
## NOT ported: the rest of `ControlSettings` (touch/joystick/colorblind/
## goalIndicators/legend/renderQuality/etc.) — no consumer exists yet for
## any of them (no touch input, no colour-blind-aware HUD styling, no
## render-quality tiers). Porting inert settings before their consumers
## exist would just be dead data, against this project's own conventions.

const SAVE_PATH := "user://settings.json"

const VALID_DIFFICULTIES := ["easy", "medium", "hard", "explorer"]
const VALID_SPRINT_MODES := ["hold", "toggle"]

var volume: float = 0.6
var muted: bool = false
var difficulty: String = "medium"
## "hold" (default, only mode implemented in PlayerMovement.gd before this
## slice) or "toggle" (press once to start sprinting, press again to stop).
var sprint_mode: String = "hold"

func _ready() -> void:
	load_settings()

func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	save_settings()

func set_muted(m: bool) -> void:
	muted = m
	save_settings()

func set_difficulty(d: String) -> void:
	if not VALID_DIFFICULTIES.has(d):
		return
	difficulty = d
	save_settings()

func set_sprint_mode(mode: String) -> void:
	if not VALID_SPRINT_MODES.has(mode):
		return
	sprint_mode = mode
	save_settings()

## Effective playback volume for AudioService — 0 when muted, matching the
## TS source's `muted ? 0 : volume` pattern at every `audio.play*()` call site.
func effective_volume() -> float:
	return 0.0 if muted else volume

## See AtomicSave.gd — same atomic-write reasoning as ProgressStore.gd.
func save_settings() -> void:
	AtomicSave.write_json(SAVE_PATH, {
		"volume": volume,
		"muted": muted,
		"difficulty": difficulty,
		"sprint_mode": sprint_mode,
	})

func load_settings() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		# Timestamped for the same reason as ProgressStore.load_progress() —
		# see its comment and plan31-08.md "Część 16".
		push_warning("[%s] SettingsStore: %s did not contain a JSON object, ignoring" % [Time.get_datetime_string_from_system(), SAVE_PATH])
		return

	var loaded_volume: float = parsed.get("volume", 0.6)
	volume = clampf(loaded_volume, 0.0, 1.0)
	muted = parsed.get("muted", false)
	var loaded_difficulty: String = parsed.get("difficulty", "medium")
	difficulty = loaded_difficulty if VALID_DIFFICULTIES.has(loaded_difficulty) else "medium"
	var loaded_sprint_mode: String = parsed.get("sprint_mode", "hold")
	sprint_mode = loaded_sprint_mode if VALID_SPRINT_MODES.has(loaded_sprint_mode) else "hold"
