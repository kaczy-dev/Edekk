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

## A `var`, not a `const` — GUT test scripts that call reset_progress()
## override this in before_all() to a disposable path (see
## tests/integration/test_gameplay.gd and test_level7.gd), so a local test
## run no longer needs the manual cp-before/cp-after backup dance around
## the real save documented in plan31-08.md's automated-smoke-test
## sections (Faza 0 point 3 of docs/ROADMAP.md — "GUT przestaje pisać do
## prawdziwego progress.json"). Real gameplay never touches this — only
## test setup reassigns it.
var save_path := "user://progress.json"

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
var level_progress: Dictionary = { }
## level_id -> Array[String] of npc obj_ids talked to
var talked_npcs: Dictionary = { }
## level_id -> best completion time in ms
var best_level_times: Dictionary = { }
## rpg.md section 6 backlog ("Ekonomia miejska") — wallet in złoty (whole
## units, no grosze, matching this game's other integer stats like HP).
## Purely additive field: an old save simply loads `money = 0` via the
## `.get()` default below, no SCHEMA_VERSION bump needed (same reasoning
## the file's own header gives for why best_level_times etc. didn't need one).
var money: int = 0

## rpg.md section 11 backlog ("Podsumowanie dnia") — resets on
## TimeManager.day_changed (_on_day_changed() below), deliberately NOT
## persisted across save/load (a partial day's stats lost on app restart is
## an acceptable simplification — the summary is a nice-to-have toast, not
## a played record).
const LOW_MONEY_THRESHOLD := 5
var day_earned: int = 0
var day_spent: int = 0
var day_fights_won: int = 0

## rpg.md section 11 backlog ("Osiągnięcia/statystyki życiowe") — unlike
## day_earned/day_spent/day_fights_won above, these never reset; they're the
## running lifetime totals a future achievements/stats screen would read.
## Purely additive fields on an existing save (old saves load 0 via the
## `.get()` default in load_progress(), same reasoning as `money`'s header
## comment) — no SCHEMA_VERSION bump needed.
var total_enemies_defeated: int = 0
var total_money_earned: int = 0
var total_days_survived: int = 0

## rpg.md section 11 backlog ("Historia transakcji") — newest entry last (a
## future journal UI can just iterate and reverse for display, matching how
## `level_progress`/`talked_npcs` etc. read as plain data here with no UI
## opinion baked in). Each entry: {"type": "earn"|"spend", "amount": int,
## "day": int, "hour": int, "minute": int} from TimeManager, so a future
## filter/sort (sekcja 11b) has a real timestamp to work with. Capped via
## `_record_transaction()` below — an unbounded array in a save file that's
## meant to grow over many play sessions is exactly the kind of thing that
## quietly becomes a multi-MB JSON blob if nothing trims it.
const MAX_TRANSACTION_HISTORY := 100
var transaction_history: Array[Dictionary] = []

## rpg.md section 11 backlog ("Log/dziennik questów") — persisted record of
## every quest step ever completed, across every level, newest last. Each
## entry: {"level_id": String, "quest_id": String, "day": int, "hour": int,
## "minute": int}. Idempotent per (level_id, quest_id) pair — called from
## LevelRuntime._update_status() on the transition to done, guarded there by
## `_known_done_quest_ids` too, but guarded again here so a save/reload
## mid-level (or a future second caller) can't double-record the same
## completion. Unlike `transaction_history` this is NOT capped — a player's
## full quest history across 6 levels is a small, bounded list (one entry
## per QuestStepData ever authored), nothing like the unbounded stream of
## purchases a long play session could generate.
var quest_completion_history: Array[Dictionary] = []

## rpg.md backlog ("Ulubione miejsca") — bookmarked interactables the player
## has marked for quick reference (vending machines, quest NPCs — anything
## whose script exposes `get_favorite_label()`, see InteractionDetector.gd).
## Keyed by (level_id, obj_id) pair, same identity NpcActor/VendingMachine
## already carry — no new id scheme invented. Each entry:
## {"level_id": String, "obj_id": String, "label": String}. Small and
## bounded (one entry per placed interactable a player could ever favorite
## across 6 levels), so unlike `transaction_history` this is NOT capped.
var favorite_places: Array[Dictionary] = []


func is_favorite(level_id: String, obj_id: String) -> bool:
	for entry in favorite_places:
		if entry.level_id == level_id and entry.obj_id == obj_id:
			return true
	return false


## Toggles the (level_id, obj_id) bookmark on/off, returns the new state
## (true = now favorited) so the caller (LevelRuntime, on
## EventBus.favorite_toggle_requested) can show the right toast without a
## separate is_favorite() call racing against this one.
func toggle_favorite(level_id: String, obj_id: String, label: String) -> bool:
	for i in range(favorite_places.size()):
		var entry: Dictionary = favorite_places[i]
		if entry.level_id == level_id and entry.obj_id == obj_id:
			favorite_places.remove_at(i)
			save_progress()
			return false
	favorite_places.append({ "level_id": level_id, "obj_id": obj_id, "label": label })
	save_progress()
	return true


func get_favorites() -> Array[Dictionary]:
	return favorite_places


func has_completed_quest(level_id: String, quest_id: String) -> bool:
	for entry in quest_completion_history:
		if entry.level_id == level_id and entry.quest_id == quest_id:
			return true
	return false


func record_quest_completed(level_id: String, quest_id: String) -> void:
	if has_completed_quest(level_id, quest_id):
		return
	quest_completion_history.append(
		{
			"level_id": level_id,
			"quest_id": quest_id,
			"day": TimeManager.current_day,
			"hour": TimeManager.current_hour,
			"minute": TimeManager.current_minute,
		}
	)
	save_progress()


func _record_transaction(type: String, amount: int) -> void:
	transaction_history.append(
		{
			"type": type,
			"amount": amount,
			"day": TimeManager.current_day,
			"hour": TimeManager.current_hour,
			"minute": TimeManager.current_minute,
		}
	)
	if transaction_history.size() > MAX_TRANSACTION_HISTORY:
		transaction_history = transaction_history.slice(
			transaction_history.size() - MAX_TRANSACTION_HISTORY
		)


func add_money(amount: int) -> void:
	if amount <= 0:
		return
	money += amount
	day_earned += amount
	total_money_earned += amount
	_record_transaction("earn", amount)
	save_progress()
	EventBus.money_changed.emit(money)


## Returns false (and changes nothing) if the wallet can't cover `amount` —
## callers (VendingMachine.gd) check this return value instead of the
## caller pre-checking `money >= amount` itself, so the deduct-and-check
## can never race against itself.
func spend_money(amount: int) -> bool:
	if amount <= 0 or money < amount:
		return false
	money -= amount
	day_spent += amount
	_record_transaction("spend", amount)
	save_progress()
	EventBus.money_changed.emit(money)
	if money < LOW_MONEY_THRESHOLD:
		EventBus.toast_requested.emit("Zostało tylko %d zł..." % money)
	return true


## Connected in _ready() below. Fires the previous day's summary as a toast
## (skipped entirely on a day with no activity — a silent day isn't worth
## interrupting the player for) then resets the counters for the new day.
func _on_day_changed(_new_day: int) -> void:
	if day_earned > 0 or day_spent > 0 or day_fights_won > 0:
		EventBus.toast_requested.emit(
			"Podsumowanie dnia: +%d zł, -%d zł, %d starć" % [day_earned, day_spent, day_fights_won]
		)
	day_earned = 0
	day_spent = 0
	day_fights_won = 0
	total_days_survived += 1
	save_progress()


func _on_enemy_died(_obj_id: String) -> void:
	day_fights_won += 1
	total_enemies_defeated += 1


## rpg.md section 6 backlog ("Reputacja w dzielnicach") — zone_id (String,
## e.g. a level id or a named district) -> reputation int, no fixed min/max
## (callers decide what range makes sense for their own gating, e.g. a shop
## checking `>= 10` for a discount). Deliberately lives HERE rather than as
## a ninth autoload — rpg.md's own architectural note flagged that a
## dedicated ReputationStore would be another singleton for state that's
## exactly as "genuinely global, persisted, cross-scene" as the rest of
## this file already is, no different reason to split it out.
var reputation: Dictionary = { }

## rpg.md section 11 backlog ("Szybki zapis / mid-level resume") — a
## checkpoint distinct from `level_progress`'s completed/items_collected:
## the exact spot inside a level to drop the player back into, instead of
## always restarting a level at its authored spawn point (LevelBuilder's
## Player node position) with full HP. `resume_hp` of -1 means "no HP
## captured yet" (a fresh save from before this field existed, or a
## checkpoint written before HealthComponent existed on Player) — callers
## must check this before applying it, same defensive pattern as
## `best_level_times`'s `prev_best == null` check above.
var resume_level_id: String = ""
var resume_pos_x: float = 0.0
var resume_pos_y: float = 0.0
var resume_hp: int = -1


## Called periodically by LevelRuntime (Timer, see its _ready()) while a
## level is in progress — NOT idempotent-guarded like the rest of this file
## (record_item_collected etc.), because a checkpoint's whole point is to
## keep overwriting itself with the player's latest position, unlike a
## one-time event.
func save_checkpoint(level_id: String, position: Vector2, hp: int) -> void:
	resume_level_id = level_id
	resume_pos_x = position.x
	resume_pos_y = position.y
	resume_hp = hp
	save_progress()


## Called on level completion (LevelRuntime._on_goal_reached) and
## reset_progress() — a finished level has nothing left to resume mid-way
## through, and "Kontynuuj" should fall back to unlocked_levels.back()'s
## normal spawn point instead of replaying a stale mid-level position.
func clear_checkpoint() -> void:
	resume_level_id = ""
	resume_pos_x = 0.0
	resume_pos_y = 0.0
	resume_hp = -1
	save_progress()


func has_checkpoint_for(level_id: String) -> bool:
	return resume_level_id == level_id


func get_checkpoint_position() -> Vector2:
	return Vector2(resume_pos_x, resume_pos_y)


func get_reputation(zone_id: String) -> int:
	return reputation.get(zone_id, 0)


## Emits EventBus.reputation_changed so a HUD/dialogue system can react
## without reaching into ProgressStore directly (rule 6) — no listener
## exists yet (same "add the signal once state actually needs to notify
## something" reasoning as EventBus.gd's other additions this session).
func add_reputation(zone_id: String, amount: int) -> void:
	if amount == 0:
		return
	var new_value: int = get_reputation(zone_id) + amount
	reputation[zone_id] = new_value
	save_progress()
	EventBus.reputation_changed.emit(zone_id, new_value)


func _ready() -> void:
	load_progress()
	TimeManager.day_changed.connect(_on_day_changed)
	EventBus.enemy_died.connect(_on_enemy_died)


func items_collected_for(level_id: String) -> Array[String]:
	var entry: Dictionary = level_progress.get(level_id, { })
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
	var entry: Dictionary = level_progress.get(level_id, { })
	return entry.get("completed", false)


func is_unlocked(level_id: String) -> bool:
	return unlocked_levels.has(level_id)


## Mirrors gameStore.pickUp: idempotent per obj_id, autosaves immediately
## (every zustand `set()` in the TS store synchronously persists too).
func record_item_collected(level_id: String, obj_id: String) -> void:
	var entry: Dictionary = level_progress.get(
		level_id,
		{ "completed": false, "items_collected": [] },
	)
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
	var entry: Dictionary = level_progress.get(
		level_id,
		{ "completed": false, "items_collected": [] },
	)
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
	AtomicSave.write_json(
		save_path,
		{
			"schema_version": SCHEMA_VERSION,
			"unlocked_levels": unlocked_levels,
			"level_progress": level_progress,
			"talked_npcs": talked_npcs,
			"best_level_times": best_level_times,
			"money": money,
			"reputation": reputation,
			"total_enemies_defeated": total_enemies_defeated,
			"total_money_earned": total_money_earned,
			"total_days_survived": total_days_survived,
			"transaction_history": transaction_history,
			"quest_completion_history": quest_completion_history,
			"favorite_places": favorite_places,
			"resume_level_id": resume_level_id,
			"resume_pos_x": resume_pos_x,
			"resume_pos_y": resume_pos_y,
			"resume_hp": resume_hp,
		},
	)


func load_progress() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		# Timestamped explicitly (not just relying on the engine log's own
		# per-session header) — a corrupted/truncated save falling back to
		# defaults is exactly the kind of silent data loss Część 16's crash
		# logger exists to make traceable after the fact.
		push_warning(
			"[%s] ProgressStore: %s did not contain a JSON object, ignoring"
			% [Time.get_datetime_string_from_system(), save_path]
		)
		return

	# Missing schema_version means "written before this field existed" —
	# treat as version 1 (the only shape that ever existed until now), not
	# an error. A future version bump adds an `if loaded_version < N:
	# migrate(parsed)` branch here rather than changing the fields read
	# below in place.
	var loaded_version: int = parsed.get("schema_version", 1)
	if loaded_version > SCHEMA_VERSION:
		push_warning(
			"[%s] ProgressStore: save schema_version %d is newer than this build supports (%d) — loading anyway, some fields may be ignored"
			% [Time.get_datetime_string_from_system(), loaded_version, SCHEMA_VERSION]
		)

	var loaded_unlocked: Array[String] = []
	for id in parsed.get("unlocked_levels", ["1"]):
		loaded_unlocked.append(str(id))
	unlocked_levels = loaded_unlocked if loaded_unlocked.size() > 0 else ["1"]
	level_progress = parsed.get("level_progress", { })
	talked_npcs = parsed.get("talked_npcs", { })
	best_level_times = parsed.get("best_level_times", { })
	money = parsed.get("money", 0)
	reputation = parsed.get("reputation", { })
	total_enemies_defeated = parsed.get("total_enemies_defeated", 0)
	total_money_earned = parsed.get("total_money_earned", 0)
	total_days_survived = parsed.get("total_days_survived", 0)
	var loaded_history: Array[Dictionary] = []
	loaded_history.assign(parsed.get("transaction_history", []))
	transaction_history = loaded_history
	var loaded_quest_history: Array[Dictionary] = []
	loaded_quest_history.assign(parsed.get("quest_completion_history", []))
	quest_completion_history = loaded_quest_history
	var loaded_favorites: Array[Dictionary] = []
	loaded_favorites.assign(parsed.get("favorite_places", []))
	favorite_places = loaded_favorites
	resume_level_id = parsed.get("resume_level_id", "")
	resume_pos_x = parsed.get("resume_pos_x", 0.0)
	resume_pos_y = parsed.get("resume_pos_y", 0.0)
	resume_hp = parsed.get("resume_hp", -1)


## Wipes all progress on disk and in memory — no UI hooks up to this yet
## (matches gameStore.resetProgress not being reachable without the
## Settings/menu UI it lives behind in the TS app).
func reset_progress() -> void:
	unlocked_levels = ["1"]
	level_progress = { }
	talked_npcs = { }
	best_level_times = { }
	money = 0
	reputation = { }
	total_enemies_defeated = 0
	total_money_earned = 0
	total_days_survived = 0
	transaction_history = []
	quest_completion_history = []
	favorite_places = []
	resume_level_id = ""
	resume_pos_x = 0.0
	resume_pos_y = 0.0
	resume_hp = -1
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
