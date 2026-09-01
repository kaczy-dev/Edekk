extends Node
## Autoload singleton — Godot's equivalent of the non-progress persisted
## slice of src/store/gameStore.ts (zustand `persist`): volume, muted,
## difficulty, and the one `ControlSettings` field with an actual gameplay
## consumer so far (`sprintMode`). Same "genuinely global, persisted,
## cross-scene state" bar as ProgressStore.gd — third autoload, still used
## sparingly (each one has a distinct, non-overlapping responsibility).
##
## NOT ported: the rest of `ControlSettings` (colorblind/goalIndicators/
## legend/renderQuality/etc.) — no consumer exists yet for any of them (no
## colour-blind-aware HUD styling, no render-quality tiers). Porting inert
## settings before their consumers exist would just be dead data, against
## this project's own conventions. `mobile_controls` below IS ported now —
## rpg.md section 8 (2026-08-31) gave it a real consumer (MobileControls.tscn).

## A `var`, not a `const` — same reasoning as ProgressStore.save_path: GUT
## tests that call set_keybind()/set_difficulty()/etc. (which all
## autosave) redirect this to a disposable path in before_all() instead of
## touching the real user://settings.json. See tests/save/test_input_rebind.gd.
var SAVE_PATH := "user://settings.json"

const VALID_DIFFICULTIES := ["easy", "medium", "hard", "explorer"]
const VALID_SPRINT_MODES := ["hold", "toggle"]
const VALID_MOBILE_CONTROLS := ["auto", "on", "off"]

## rpg.md backlog ("Rebindowanie klawiszy") — the subset of project.godot's
## [input] actions actually meaningful to let a player rebind from a menu.
## Deliberately excludes UI-navigation-only Godot builtins (ui_accept etc. —
## nothing here consumes them directly) and joypad-only concerns (rebinding
## a gamepad button isn't in scope for this pass; only each action's
## InputEventKey is touched by set_keybind()/reset_keybind() below, any
## InputEventJoypadButton/Motion already on the action is left untouched).
const REBINDABLE_ACTIONS := [
	"move_up",
	"move_down",
	"move_left",
	"move_right",
	"interact",
	"inventory",
	"pause",
	"sprint",
	"hop",
	"attack",
	"quick_save",
	"favorite",
]

## The physical_keycode each action ships with in project.godot's [input]
## section — used both as reset_keybind()'s fallback and as
## get_key_label()'s fallback for an action the player has never touched.
## Kept as data here (not re-derived from InputMap at runtime) because
## InputMap IS the mutable thing set_keybind() changes — once a key has been
## rebound, InputMap no longer remembers what the *original* default was.
const DEFAULT_KEYBINDS := {
	"move_up": KEY_W,
	"move_down": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"interact": KEY_E,
	"inventory": KEY_I,
	"pause": KEY_ESCAPE,
	"sprint": KEY_SHIFT,
	"hop": KEY_SPACE,
	"attack": KEY_J,
	"quick_save": KEY_F5,
	"favorite": KEY_F,
}

var volume: float = 0.6
var muted: bool = false
var difficulty: String = "medium"
## "hold" (default, only mode implemented in PlayerMovement.gd before this
## slice) or "toggle" (press once to start sprinting, press again to stop).
var sprint_mode: String = "hold"
## "auto" (default — shown when DisplayServer.is_touchscreen_available()),
## "on" (always), "off" (never). See MobileControls.gd's should_show().
var mobile_controls: String = "auto"

## action name -> physical_keycode (int), only for actions the player has
## actually rebound away from DEFAULT_KEYBINDS — an action absent from this
## dict simply uses whatever project.godot already ships (no entry needed
## just to mirror the default, same "purely additive, .get()-defaulted"
## shape as ProgressStore's newer fields).
var custom_keybinds: Dictionary = { }


func _ready() -> void:
	load_settings()
	apply_keybinds()


## Re-applies every saved rebind to the live InputMap — called once at
## startup (after load_settings()) and also right after a single
## set_keybind()/reset_keybind() call so the change takes effect
## immediately, not just on next launch.
func apply_keybinds() -> void:
	for action: String in custom_keybinds:
		_apply_single_keybind(action, custom_keybinds[action])


func _apply_single_keybind(action: String, physical_keycode: int) -> void:
	if not InputMap.has_action(action):
		return
	# Only the action's own InputEventKey is replaced — any
	# InputEventJoypadButton/Motion already bound to it (see project.godot)
	# is left alone, so rebinding a keyboard key never breaks gamepad play.
	for existing_event in InputMap.action_get_events(action):
		if existing_event is InputEventKey:
			InputMap.action_erase_event(action, existing_event)
	var new_event := InputEventKey.new()
	new_event.physical_keycode = physical_keycode
	InputMap.action_add_event(action, new_event)


## Rebinds `action`'s keyboard key to `physical_keycode`. If another
## rebindable action is currently using the same key, that action's
## keyboard binding is cleared (not swapped) — two actions firing off one
## key press would be an ambiguous, surprising state, and a silent swap
## would be just as surprising from the other action's side. The player
## sees the freed-up action lose its key label in the rebind menu and can
## assign it a new one explicitly.
func set_keybind(action: String, physical_keycode: int) -> void:
	if not REBINDABLE_ACTIONS.has(action):
		return
	for other_action in REBINDABLE_ACTIONS:
		if other_action != action and _current_keycode(other_action) == physical_keycode:
			custom_keybinds[other_action] = -1 # -1 = "no keyboard key bound"
			_clear_key_events(other_action)
	custom_keybinds[action] = physical_keycode
	_apply_single_keybind(action, physical_keycode)
	save_settings()


func _clear_key_events(action: String) -> void:
	if not InputMap.has_action(action):
		return
	for existing_event in InputMap.action_get_events(action):
		if existing_event is InputEventKey:
			InputMap.action_erase_event(action, existing_event)


## Restores `action`'s key to project.godot's shipped default.
func reset_keybind(action: String) -> void:
	if not REBINDABLE_ACTIONS.has(action):
		return
	custom_keybinds.erase(action)
	if DEFAULT_KEYBINDS.has(action):
		_apply_single_keybind(action, DEFAULT_KEYBINDS[action])
	save_settings()


func reset_all_keybinds() -> void:
	custom_keybinds = { }
	for action in DEFAULT_KEYBINDS:
		_apply_single_keybind(action, DEFAULT_KEYBINDS[action])
	save_settings()


func _current_keycode(action: String) -> int:
	if custom_keybinds.has(action):
		return custom_keybinds[action]
	return DEFAULT_KEYBINDS.get(action, -1)


## Human-readable label for a rebind menu row, e.g. "W", "Spacja", "Esc" —
## reads InputMap directly (not DEFAULT_KEYBINDS/custom_keybinds) so it
## always reflects whatever key is actually bound right now, including the
## "-1 -> no key bound" case set_keybind() above can leave another action in.
func get_key_label(action: String) -> String:
	if custom_keybinds.get(action, 0) == -1:
		return "—"
	if not InputMap.has_action(action):
		return "—"
	for existing_event in InputMap.action_get_events(action):
		if existing_event is InputEventKey:
			return OS.get_keycode_string(existing_event.physical_keycode)
	return "—"


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


func set_mobile_controls(mode: String) -> void:
	if not VALID_MOBILE_CONTROLS.has(mode):
		return
	mobile_controls = mode
	save_settings()


## Effective playback volume for AudioService — 0 when muted, matching the
## TS source's `muted ? 0 : volume` pattern at every `audio.play*()` call site.
func effective_volume() -> float:
	return 0.0 if muted else volume


## See AtomicSave.gd — same atomic-write reasoning as ProgressStore.gd.
func save_settings() -> void:
	AtomicSave.write_json(
		SAVE_PATH,
		{
			"volume": volume,
			"muted": muted,
			"difficulty": difficulty,
			"sprint_mode": sprint_mode,
			"mobile_controls": mobile_controls,
			"custom_keybinds": custom_keybinds,
		},
	)


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
		push_warning(
			"[%s] SettingsStore: %s did not contain a JSON object, ignoring"
			% [Time.get_datetime_string_from_system(), SAVE_PATH]
		)
		return

	var loaded_volume: float = parsed.get("volume", 0.6)
	volume = clampf(loaded_volume, 0.0, 1.0)
	muted = parsed.get("muted", false)
	var loaded_difficulty: String = parsed.get("difficulty", "medium")
	difficulty = loaded_difficulty if VALID_DIFFICULTIES.has(loaded_difficulty) else "medium"
	var loaded_sprint_mode: String = parsed.get("sprint_mode", "hold")
	sprint_mode = loaded_sprint_mode if VALID_SPRINT_MODES.has(loaded_sprint_mode) else "hold"
	var loaded_mobile_controls: String = parsed.get("mobile_controls", "auto")
	mobile_controls = loaded_mobile_controls if VALID_MOBILE_CONTROLS.has(loaded_mobile_controls) else "auto"

	var loaded_keybinds = parsed.get("custom_keybinds", { })
	custom_keybinds = loaded_keybinds if typeof(loaded_keybinds) == TYPE_DICTIONARY else { }
