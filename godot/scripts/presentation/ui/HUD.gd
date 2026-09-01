class_name HUD
extends CanvasLayer
## Minimal Control-based HUD replacing LevelRuntime's print()-only status
## output. Ported subset of src/components/game/HUD.tsx: quest checklist +
## inventory chips, plus a message label standing in for DialogBox (NPC/goal
## messages) until that's ported separately. Quest rows also carry a plain-
## text distance/tier hint — a simplified stand-in for the on-canvas arrow +
## coloured badge from goalTracking.ts/tierStyle.ts (see
## GoalProximity.gd and LevelRuntime._compute_tracks()).
##
## NOT ported yet — needs systems not yet migrated (see MIGRATION_MATRIX.md):
## on-canvas distance arrow + colour-blind legend (tierStyle.ts), speedrun
## timer + best-time (Save system already has the data — LevelSelectMenu
## shows it, HUD doesn't yet), quest-flash/collapse/tooltip animation
## polish. Plain default-theme Label/Panel — no custom styling yet,
## functional placeholder rather than Polygon2D-style greybox (there's no
## art to greybox here).

@onready var _quest_list: VBoxContainer = $QuestPanel/QuestList
@onready var _inventory_row: HBoxContainer = $InventoryPanel/InventoryRow
@onready var _message_label: Label = $MessageLabel
@onready var _energy_label: Label = $EnergyPanel/EnergyLabel
@onready var _interact_prompt: Label = $InteractPrompt
@onready var _compass: Label = $CompassArrow

## Shown/hidden by LevelRuntime relaying Player/InteractionDetector's
## nearest_changed signal — see InteractionDetector.gd, "Część 4".
func show_interact_prompt(text: String) -> void:
	_interact_prompt.text = text
	_interact_prompt.visible = true

func hide_interact_prompt() -> void:
	_interact_prompt.visible = false

## Below this fraction, TS shows a red bar + "Zmęczenie" pill — mirrored
## here as a text suffix instead of colour, since Label has no easy partial-
## fill bar without a custom Control/theme (ProgressBar would need a theme
## resource for the "no assets imported yet" phase this project is in).
## Also used as a plain "getting low" visual cue independent of the harder
## `is_exhausted` state (0 energy, sprint locked) LevelRuntime now tracks.
const LOW_ENERGY_THRESHOLD := 0.3

## `is_exhausted` — true once energy hit 0 and hasn't recovered past
## LevelRuntime's EXHAUSTION_RECOVER_FRACTION yet (sprint locked out even if
## energy has ticked back above the difficulty's low min_sprint_energy).
## Called from LevelRuntime.energy_changed, not pushed every frame directly —
## see LevelRuntime.gd "Część 5".
func update_energy(current_energy: float, is_exhausted: bool) -> void:
	var max_energy := Difficulty.MAX_ENERGY
	var pct := roundi(100.0 * current_energy / max_energy) if max_energy > 0.0 else 0
	var low := current_energy < max_energy * LOW_ENERGY_THRESHOLD
	var suffix := tr("UI_ENERGY_EXHAUSTED") if is_exhausted else (tr("UI_ENERGY_TIRED") if low else "")
	_energy_label.text = tr("UI_ENERGY_LABEL").format({"pct": pct}) + suffix
	_energy_label.modulate = Color(1.0, 0.2, 0.2) if is_exhausted else (Color(1.0, 0.4, 0.4) if low else Color(1, 1, 1))

var _last_statuses: Array[QuestStatus] = []
var _last_tracks: Dictionary[String, ProximityTrack] = {}

## Per-quest-id smoothed distance, chasing _last_tracks[id].dist every frame
## in _process() instead of jumping straight to the 10/s-sampled value —
## the raw sample rate is fine for the *logic* (LevelRuntime._process()),
## but rendering it directly made the HUD number visibly step every ~100ms.
## React's version smoothed this continuously via requestAnimationFrame; this
## is the Godot equivalent. See docs/migration/MIGRATION_MATRIX.md, "Część 6".
var _displayed_dist: Dictionary[String, float] = {}
const PROXIMITY_LERP_RATE := 15.0

## quest.id -> its row Label, so _process() can restyle the hint text in
## place every frame without tearing down/rebuilding the whole list at 60fps
## (queue_free()+recreate per frame is the kind of churn that's fine at the
## ~10/s update_status() rate but not worth paying for a smooth per-frame
## number). Structural rebuilds (quest added/completed/reordered) still go
## through _render_quest_list(), only called from update_status().
var _quest_rows: Dictionary[String, Label] = {}
## quest.id -> "[x] Label (n/m)" without the trailing proximity hint, cached
## so _process() can just append the freshly-lerped hint each frame instead
## of recomputing the whole line.
var _quest_base_text: Dictionary[String, String] = {}

func set_message(text: String) -> void:
	_message_label.text = text

## `statuses` — QuestUtils.compute_quests() result. `inventory` —
## Inventory.inventory_from_collected() result (StringName -> int).
## `items` — ItemRegistry.load_all() result (StringName -> ItemData).
func update_status(statuses: Array[QuestStatus], inventory: Dictionary, items: Dictionary) -> void:
	_last_statuses = statuses
	_render_quest_list()

	for child in _inventory_row.get_children():
		child.queue_free()
	var has_items := false
	for item_id in inventory:
		var count: int = inventory[item_id]
		if count <= 0:
			continue
		has_items = true
		var item: ItemData = items.get(item_id)
		var chip := Label.new()
		chip.text = "%s x%d" % [item.emoji if item else "?", count]
		_inventory_row.add_child(chip)
	if not has_items:
		var empty := Label.new()
		empty.text = tr("Pusty plecak")
		_inventory_row.add_child(empty)

## `tracks` — quest_id -> ProximityTrack, from LevelRuntime._compute_tracks(),
## sampled at 10/s. Stores the raw target only — _process() does the actual
## per-frame smoothing/rendering, see _displayed_dist above.
func update_proximity(tracks: Dictionary[String, ProximityTrack]) -> void:
	_last_tracks = tracks
	for quest_id in tracks:
		if not _displayed_dist.has(quest_id):
			# First sighting of this quest's track this level (or its nearest
			# target just changed) — snap instead of lerping in from 0, which
			# would render a bogus "~0 kr." for a frame.
			_displayed_dist[quest_id] = tracks[quest_id].dist
	for quest_id in _displayed_dist.keys():
		if not tracks.has(quest_id):
			_displayed_dist.erase(quest_id)

func _process(delta: float) -> void:
	if _last_tracks.is_empty():
		_compass.visible = false
		return
	for quest_id in _last_tracks:
		var target := _last_tracks[quest_id].dist
		_displayed_dist[quest_id] = lerpf(_displayed_dist[quest_id], target, PROXIMITY_LERP_RATE * delta)
		_update_hint_row(quest_id)
	_update_compass()

## rpg.md section 11 backlog ("Mapa/wskaźnik celu questa") — points the
## compass arrow at whichever active quest is currently nearest (by raw
## dist, not the smoothed _displayed_dist — a compass heading jumping to a
## new target should snap instantly, unlike the numeric distance label which
## intentionally lerps). Hidden when the "at" tier is reached (arm's length
## from the target — a heading arrow stops being useful information once
## you're standing on the thing).
func _update_compass() -> void:
	var nearest_id := ""
	var nearest_dist := INF
	for quest_id in _last_tracks:
		var track: ProximityTrack = _last_tracks[quest_id]
		if track.dist < nearest_dist:
			nearest_dist = track.dist
			nearest_id = quest_id
	if nearest_id == "" or _last_tracks[nearest_id].tier == "at":
		_compass.visible = false
		return
	var direction: Vector2 = _last_tracks[nearest_id].direction
	if direction == Vector2.ZERO:
		_compass.visible = false
		return
	_compass.visible = true
	_compass.rotation = direction.angle()

const _TIER_KEYS := {"at": "UI_TIER_AT", "near": "UI_TIER_NEAR", "mid": "UI_TIER_MID", "far": "UI_TIER_FAR"}

func _update_hint_row(quest_id: String) -> void:
	var row: Label = _quest_rows.get(quest_id)
	var base: String = _quest_base_text.get(quest_id, "")
	if row == null:
		return
	var track: ProximityTrack = _last_tracks.get(quest_id)
	if track == null:
		row.text = base
		return
	var steps := maxi(1, roundi(_displayed_dist[quest_id] / 32.0))
	var tier_label := tr(_TIER_KEYS.get(track.tier, "UI_TIER_FAR"))
	var hint := tr("UI_PROXIMITY_HINT").format({"tier": tier_label, "steps": steps})
	row.text = "%s  %s" % [base, hint]

func _render_quest_list() -> void:
	for child in _quest_list.get_children():
		child.queue_free()
	_quest_rows.clear()
	_quest_base_text.clear()
	for status in _last_statuses:
		var quest: QuestStepData = status.quest
		var prefix := "[x] " if status.done else ("[!] " if status.ready else "[ ] ")
		var suffix := " (%d/%d)" % [status.current, status.total] if status.total > 1 else ""
		var base := prefix + quest.label + suffix
		var row := Label.new()
		row.text = base
		row.modulate = Color(1, 1, 1, 0.55) if status.done else Color(1, 1, 1, 1)
		_quest_list.add_child(row)
		if not status.done:
			_quest_rows[quest.id] = row
			_quest_base_text[quest.id] = base
			_update_hint_row(quest.id)
