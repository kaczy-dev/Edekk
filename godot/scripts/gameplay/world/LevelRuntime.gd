extends Node2D
## Level root: builds a LevelData into the scene, tracks the run-session
## state TS split across gameStore (collected/talked/completed), and
## recomputes quest status through the ported Inventory/QuestUtils on every
## change. Displays it via HUD.gd (godot/scenes/ui/HUD.tscn); console prints
## for individual events (collected/talked/gift/goal) stay as a lightweight
## dev log alongside the visible HUD. Persists progress incrementally via
## the ProgressStore autoload (see scripts/infrastructure/ProgressStore.gd),
## same "every change autosaves" behaviour as gameStore's zustand `persist`.

const HudScene := preload("res://scenes/ui/HUD.tscn")

@export var level: LevelData

var _items: Dictionary
var _collected_ids: Array[String] = []
var _talked: Array[String] = []
var _level_completed := false
var _hud: HUD
var _start_ticks_msec: int
var _proximity_accum := 0.0
const PROXIMITY_TICK_SEC := 0.1

## Fraction of MAX_ENERGY the cat must recover to before exhaustion lifts and
## sprint becomes available again — separate from (and typically higher than)
## Difficulty's `min_sprint_energy`, so hitting 0 always means a real
## "catch your breath" beat instead of instantly re-allowing sprint the
## moment energy ticks past a low `min_sprint_energy` threshold (e.g. 8 on
## medium). See docs/migration/MIGRATION_MATRIX.md, Sprint "Część 5".
const EXHAUSTION_RECOVER_FRACTION := 0.3

## Emitted whenever _update_energy() recomputes state — HUD listens instead
## of LevelRuntime pushing update_energy() directly, decoupling "who reacts
## to energy changing" from "who computes it" (only one listener today, but
## matches the signal-driven pattern used for collected/reached/talked).
signal energy_changed(current_energy: float, is_exhausted: bool)

var _energy: float = 0.0
var _is_exhausted := false
## rpg.md section 11 backlog ("Powiadomienia o niskiej energii") —
## threshold-crossing flag, not a per-frame check, so the toast fires once
## when energy first drops below LOW_ENERGY_THRESHOLD and can fire again
## after a real recovery above it, instead of spamming every frame spent
## below the line.
const LOW_ENERGY_THRESHOLD := 20.0
var _was_low_energy := false

## rpg.md section 11 backlog ("Szybki zapis / mid-level resume") — periodic
## checkpoint of the player's position + HP, distinct from the item/quest
## autosave above which only ever adds to permanent progress. Deliberately
## a plain Timer on an interval rather than tied to every physics frame
## (position drifts constantly; writing a full JSON save 60x/sec would be
## wasteful) or only to discrete events (item/talk/goal) — those already
## call _update_status() but a player can walk far between two such events
## with nothing to checkpoint the movement.
const CHECKPOINT_INTERVAL_SEC := 5.0

## Część 12 (plan31-08.md): debug-console-only bonus inventory, merged into
## the real (obj_id-derived) inventory in _update_status()/_compute_tracks().
## Not part of the persisted save — a debug `/give_item` grant is
## session-only, matching what a cheat command should do. Kept separate from
## `_collected_ids` rather than synthesizing a fake collected object,
## because Inventory.inventory_from_collected() derives item_id by looking
## up a matching LevelObjectData for each obj_id — a debug-given item has no
## such placed object to look up.
var _debug_bonus_inventory: Dictionary[StringName, int] = { }


## Called by DebugConsole.gd's `/give_item` command.
func debug_give_item(item_id: StringName, count: int = 1) -> void:
	_debug_bonus_inventory[item_id] = _debug_bonus_inventory.get(item_id, 0) + count
	_update_status()


## Called by DebugConsole.gd's `/god` command — same effect every frame
## _update_energy() runs, applied before the normal drain/regen math so it
## always wins outright rather than fighting it.
var debug_god_mode := false


func _ready() -> void:
	_items = ItemRegistry.load_all()
	var enemies := EnemyRegistry.load_all()
	_collected_ids = ProgressStore.items_collected_for(level.id)
	_talked = ProgressStore.talked_for(level.id)
	_level_completed = ProgressStore.is_completed(level.id)
	_start_ticks_msec = Time.get_ticks_msec()
	_energy = Difficulty.get_config(SettingsStore.difficulty).start_energy

	var has_background := _setup_background()
	_setup_door_decoration()

	_hud = HudScene.instantiate()
	add_child(_hud)
	energy_changed.connect(_hud.update_energy)
	EventBus.energy_restore_requested.connect(restore_energy)
	LevelBuilder.build(self, level, _collected_ids, has_background, _items, enemies)

	# EventBus instead of connecting to each spawned node's own signal (the
	# old LevelBuilder.build() return value existed only for that) — see
	# EventBus.gd, "Część 9". One connection per level instance; auto-
	# disconnected when this LevelRuntime is freed on scene change.
	EventBus.item_collected.connect(_on_item_collected)
	EventBus.goal_reached.connect(_on_goal_reached)
	EventBus.npc_talked.connect(_on_npc_talked)
	EventBus.favorite_toggle_requested.connect(_on_favorite_toggle_requested)

	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		var atmosphere := AtmosphereFX.new()
		add_child(atmosphere)
		atmosphere.setup(level, player)
		_setup_camera(player)
		var detector := player.get_node_or_null("InteractionArea") as InteractionDetector
		if detector != null:
			detector.nearest_changed.connect(_on_nearest_interactable_changed)
		_resume_checkpoint(player)
		_setup_checkpoint_timer(player)
	_update_status()


## Repositions the player and restores HP from a checkpoint saved earlier in
## THIS level (a checkpoint from a different level, e.g. an old one left
## over before it was cleared, must never leak position/HP into the wrong
## level — same reasoning as items_collected_for()/talked_for() scoping by
## level_id above). `resume_hp <= -1` means no HP was ever captured (old
## save, or checkpoint predates HealthComponent) — leave HP at whatever
## HealthComponent's own _ready()/configure() already set, don't guess.
func _resume_checkpoint(player: Node) -> void:
	if not ProgressStore.has_checkpoint_for(level.id):
		return
	player.global_position = ProgressStore.get_checkpoint_position()
	if ProgressStore.resume_hp <= -1:
		return
	var health := player.get_node_or_null("HealthComponent") as HealthComponent
	if health != null:
		health.current_hp = mini(ProgressStore.resume_hp, health.max_hp)
		health.health_changed.emit(health.current_hp, health.max_hp)


## rpg.md backlog ("Szybki zapis / mid-level resume") — manual trigger for
## the same checkpoint _save_checkpoint() below already writes on its 5s
## Timer, so a player who's about to try something risky (a fight, a tricky
## bit of platforming) isn't stuck relying on the next automatic tick.
## Polled via is_action_just_pressed() in _process() rather than
## _unhandled_input() — same choice PlayerAttack.gd already made for
## "attack" (see its header) after finding _unhandled_input() unreliable
## under GUT's headless Input.parse_input_event() simulation; matching that
## established pattern here too, not a new discovery.
func _quick_save() -> void:
	if _level_completed:
		return
	var player = get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		return
	_save_checkpoint(player)
	EventBus.toast_requested.emit("Zapisano grę.")


func _setup_checkpoint_timer(player: Node) -> void:
	var timer := Timer.new()
	timer.wait_time = CHECKPOINT_INTERVAL_SEC
	timer.autostart = true
	timer.timeout.connect(_save_checkpoint.bind(player))
	add_child(timer)


## Skipped once the level's goal is met (_on_goal_reached below clears the
## checkpoint outright and this timer keeps running until the scene changes)
## — no point re-writing a checkpoint for a level that's already done.
func _save_checkpoint(player: Node) -> void:
	if _level_completed or not is_instance_valid(player):
		return
	var health := player.get_node_or_null("HealthComponent") as HealthComponent
	var hp := health.current_hp if health != null else -1
	ProgressStore.save_checkpoint(level.id, player.global_position, hp)


## Ported from goalTracking.ts's tick loop, simplified: no smoothing/lerp
## (React's per-frame dist/angle easing), plain text tier + distance in the
## HUD quest row instead of the on-canvas arrow/glyph — see
## MIGRATION_MATRIX.md, "Proximity/goal hints". Throttled to 10/s, not every
## physics frame — a hint readout doesn't need 60fps precision.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("quick_save"):
		_quick_save()

	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		_update_energy(delta, player)

	_proximity_accum += delta
	if _proximity_accum < PROXIMITY_TICK_SEC:
		return
	_proximity_accum = 0.0
	if player == null:
		return
	_hud.update_proximity(_compute_tracks(player.global_position))


## Ported from LevelScene.ts update(): drains while sprinting, recovers
## while fully stopped, clamped to [0, MAX_ENERGY].
##
## Stopped is now checked against actual physics velocity
## (`player.velocity.length_squared() < 0.1`) rather than the `is_moving`
## input flag the original port used — the input flag goes false the instant
## the player releases WASD, but friction keeps the cat sliding for a few
## more frames (see PlayerMovement.gd's FRICTION). That window let energy
## start recovering while the cat was still visibly moving. Checking real
## velocity fixes that without changing the "walking without sprint neither
## drains nor recovers" behaviour (velocity > threshold and not sprinting:
## neither branch fires, same as before).
##
## Exhaustion: once energy hits 0, sprint locks out completely (not just
## below Difficulty's `min_sprint_energy`) until energy recovers to
## EXHAUSTION_RECOVER_FRACTION of max — a deliberate addition beyond the TS
## source (which only ever gated sprint by the single `min_sprint_energy`
## threshold), added because hitting exactly 0 and instantly being allowed to
## sprint again the moment recovery ticks past a low threshold (4-16
## depending on difficulty) undercut the "catch your breath" beat energy is
## supposed to create.
func _update_energy(delta: float, player: Node) -> void:
	if debug_god_mode:
		_energy = Difficulty.MAX_ENERGY
		_is_exhausted = false
		player.can_sprint = true
		energy_changed.emit(_energy, _is_exhausted)
		return

	var config := Difficulty.get_config(SettingsStore.difficulty)
	var sprint_drain_mul: float = config.sprint_drain_mul
	var rest_recover_mul: float = config.rest_recover_mul
	var min_sprint_energy: float = config.min_sprint_energy

	var stopped: bool = player.velocity.length_squared() < 0.1
	if player.is_sprinting:
		_energy -= sprint_drain_mul * 6.0 * delta
	elif stopped:
		_energy += rest_recover_mul * 4.0 * delta
	_energy = clampf(_energy, 0.0, Difficulty.MAX_ENERGY)

	if _energy <= 0.0:
		_is_exhausted = true
	elif _is_exhausted and _energy >= Difficulty.MAX_ENERGY * EXHAUSTION_RECOVER_FRACTION:
		_is_exhausted = false

	player.can_sprint = not _is_exhausted and _energy >= min_sprint_energy
	energy_changed.emit(_energy, _is_exhausted)
	_check_low_energy_toast()


func _check_low_energy_toast() -> void:
	var is_low := _energy < LOW_ENERGY_THRESHOLD
	if is_low and not _was_low_energy:
		EventBus.toast_requested.emit("Energia się kończy!")
	_was_low_energy = is_low


## rpg.md section 6 backlog ("Ekonomia miejska") — public entry point for
## EventBus.energy_restore_requested (VendingMachine.gd), connected in
## _ready(). Clears `_is_exhausted` too if the restore pushes past the
## recovery fraction, same condition _update_energy() above already checks,
## so a vending-machine energy drink can end an exhaustion stun immediately
## instead of the player waiting for the next _process() tick to notice.
func restore_energy(amount: float) -> void:
	_energy = clampf(_energy + amount, 0.0, Difficulty.MAX_ENERGY)
	if _is_exhausted and _energy >= Difficulty.MAX_ENERGY * EXHAUSTION_RECOVER_FRACTION:
		_is_exhausted = false
	energy_changed.emit(_energy, _is_exhausted)
	_check_low_energy_toast()
	_check_low_energy_toast()


## Returns quest_id -> {"tier": String, "dist": float} for every undone
## "reach" or "collect" quest, mirroring useGoalTracks()'s per-quest nearest-
## point logic (no smoothing here, see _process() comment above).
## Returns quest_id -> track — the outer map is a genuine keyed collection
## so it stays a Dictionary (Godot 4.4+ typed-value Dictionary), only the
## per-entry value is a typed class instead of a Dictionary literal. See
## docs/migration/MIGRATION_MATRIX.md, Sprint 1 refactor note.
func _compute_tracks(player_pos: Vector2) -> Dictionary[String, ProximityTrack]:
	var tracks: Dictionary[String, ProximityTrack] = { }
	var inventory := Inventory.inventory_from_collected(level, _collected_ids)
	for item_id in _debug_bonus_inventory:
		inventory[item_id] = inventory.get(item_id, 0) + _debug_bonus_inventory[item_id]
	var snapshot := {
		"inventory": inventory,
		"talked": _talked,
		"level_completed": _level_completed,
		"collected": _collected_ids,
	}
	var statuses := QuestUtils.compute_quests(level, snapshot, _items)
	for status in statuses:
		if status.done:
			continue
		var quest: QuestStepData = status.quest

		if quest.kind == "reach":
			var goal: LevelObjectData = null
			for obj in level.objects:
				if obj.id == quest.obj_id:
					goal = obj
					break
			if goal == null:
				continue
			var center := goal.rect.position + goal.rect.size / 2.0
			var dist := player_pos.distance_to(center)
			var prox := GoalProximity.goal_proximity(goal)
			var dir := (center - player_pos).normalized() if dist > 0.001 else Vector2.ZERO
			tracks[quest.id] = ProximityTrack.new(
				GoalProximity.tier_for(dist, prox.at, prox.near, prox.mid),
				dist,
				dir,
			)
			continue

		if quest.kind == "collect":
			var nearest_dist := INF
			var nearest_obj: LevelObjectData = null
			for obj in level.objects:
				if obj.kind != "item" or obj.item_id != quest.item_id or _collected_ids.has(obj.id):
					continue
				var d := player_pos.distance_to(obj.rect.position + obj.rect.size / 2.0)
				if d < nearest_dist:
					nearest_dist = d
					nearest_obj = obj
			if nearest_obj == null:
				continue
			var prox2 := GoalProximity.goal_proximity(nearest_obj)
			var nearest_center := nearest_obj.rect.position + nearest_obj.rect.size / 2.0
			var dir2 := (nearest_center - player_pos).normalized() if nearest_dist > 0.001 else Vector2.ZERO
			tracks[quest.id] = ProximityTrack.new(
				GoalProximity.tier_for(nearest_dist, prox2.at, prox2.near, prox2.mid),
				nearest_dist,
				dir2,
			)
	return tracks


## Real pre-rendered scene background (see LevelBackgrounds.gd) instead of
## the grey/orange greybox — a level with no entry there just shows nothing,
## not an error (obstacle/item/goal Rect2 placement doesn't depend on it).
## Returns whether a background was actually set, so LevelBuilder knows
## whether to hide the now-redundant obstacle greybox visuals.
## Ported from LevelScene.ts's create(): `cameras.main.setBounds(0, 0, width,
## height)` + `setZoom(clamp(min(scale.width, scale.height) / 620, 0.75,
## 1.3))`. Godot's Camera2D had neither — zoom stuck at the CameraFX default
## of 1.0 and no limit_* clamp — which let the camera scroll past the
## background sprite's edge (empty engine clear color) and framed every
## level differently than the Phaser source. See MIGRATION_MATRIX.md,
## "Camera (2D)" bugfix note.
func _setup_camera(player: Node) -> void:
	var camera := player.get_node("Camera2D") as CameraFX
	if camera == null:
		return
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(level.width)
	camera.limit_bottom = int(level.height)
	var viewport_size := get_viewport_rect().size
	var z := clampf(minf(viewport_size.x, viewport_size.y) / 620.0, 0.75, 1.3)
	camera.set_base_zoom(z)


## Level 7 ("Salon") only: real sprites cropped from the TopDownHouse sheets
## (plan31-08.md "Assety graficzne"), drawn behind the emoji/obstacle
## markers at each matching LevelObjectData's rect — purely decorative, the
## actual gameplay (GoalArea/emoji, obstacle collision) stays untouched,
## this just adds real art under it.
##
## Every rect below came from flood-filling the sheet's alpha channel to
## find each sprite's exact connected-pixel bounding box (PowerShell +
## System.Drawing, no atlas/XML file existed for this pack) — then cropped
## with padding and visually inspected before committing the coordinates,
## same verify-before-use discipline as the floor tile/door. Not guessed.
const DOOR_TEXTURE_PATH := "res://assets/textures/interior/TopDownHouse_DoorsAndWindows.png"
const DOOR_TILE_RECT := Rect2i(128, 0, 32, 48) # closed brown door

const FURNITURE_TEXTURE_PATH := "res://assets/textures/interior/TopDownHouse_FurnitureState1.png"
const _FURNITURE_SPRITES := {
	"sofa": Rect2i(24, 167, 71, 68), # 2-seat sofa
	"bookshelf": Rect2i(33, 64, 46, 47),
}


func _setup_door_decoration() -> void:
	if level.id != "7":
		return
	_add_decoration_sprite("door", DOOR_TEXTURE_PATH, DOOR_TILE_RECT, -50)
	for obj_id in _FURNITURE_SPRITES:
		_add_decoration_sprite(obj_id, FURNITURE_TEXTURE_PATH, _FURNITURE_SPRITES[obj_id], -50)


func _add_decoration_sprite(
	obj_id: String,
	texture_path: String,
	tile_rect: Rect2i,
	z: int,
) -> void:
	var target_obj: LevelObjectData = null
	for obj in level.objects:
		if obj.id == obj_id:
			target_obj = obj
			break
	if target_obj == null:
		return
	var sheet := load(texture_path) as Texture2D
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = tile_rect
	var sprite := Sprite2D.new()
	sprite.texture = atlas
	sprite.centered = false
	# Scale the art to fill its LevelObjectData rect, same "art matches the
	# invisible collision/interaction Rect2" relationship LevelBuilder
	# already uses for obstacles.
	sprite.scale = Vector2(
		target_obj.rect.size.x / tile_rect.size.x,
		target_obj.rect.size.y / tile_rect.size.y,
	)
	sprite.position = target_obj.rect.position
	sprite.z_index = z # above floor (-100), below player/items (0)
	add_child(sprite)


## Relays InteractionDetector.nearest_changed to the HUD prompt — picks the
## prompt text by node type since ItemPickup/NpcActor want different verbs.
func _on_nearest_interactable_changed(target: Node2D) -> void:
	if target == null:
		_hud.hide_interact_prompt()
	elif target is NpcActor:
		_hud.show_interact_prompt(tr("UI_INTERACT_TALK"))
	elif target is ItemPickup:
		_hud.show_interact_prompt(tr("UI_INTERACT_COLLECT"))
	else:
		_hud.show_interact_prompt(tr("UI_INTERACT_GENERIC"))


func _setup_background() -> bool:
	# Level 7 ("Salon") builds its floor from a real TileSet/TileMapLayer
	# instead of loading one pre-rendered image — see LevelBackgrounds.gd,
	# build_floor_tileset(). One 32x32 tile in memory regardless of room
	# size (vs. a level.width x level.height baked bitmap), and the result
	# is an editor-paintable TileMapLayer structure — this level still
	# fills its cells in a loop rather than by hand-painting, but the door
	# is now open to do that for a future level without restructuring.
	if level.id == "7":
		var layer := TileMapLayer.new()
		layer.name = "Background"
		layer.tile_set = LevelBackgrounds.build_floor_tileset()
		layer.z_index = -100
		var tile_size := layer.tile_set.tile_size
		var cols := ceili(level.width / tile_size.x)
		var rows := ceili(level.height / tile_size.y)
		for ty in rows:
			for tx in cols:
				layer.set_cell(Vector2i(tx, ty), 0, Vector2i.ZERO)
		add_child(layer)
		return true

	var texture := LevelBackgrounds.texture_for(level.id)
	if texture == null:
		return false
	var bg := Sprite2D.new()
	bg.name = "Background"
	bg.texture = texture
	bg.centered = false
	bg.position = Vector2.ZERO
	bg.scale = Vector2(level.width / texture.get_width(), level.height / texture.get_height())
	bg.z_index = -100
	add_child(bg)
	return true


## `item_id` — the collected object's item kind, carried on EventBus's
## payload (see EventBus.gd, "Część 9") but not otherwise needed here:
## Inventory.inventory_from_collected() re-derives it from `level.objects`
## by `obj_id` when computing quest state, so this is currently unused
## beyond documenting what the bus actually delivers.
## rpg.md backlog ("Ulubione miejsca") — the only place that knows the
## current `level.id`, same reason record_item_collected()/record_talked()
## calls above are routed through here rather than ProgressStore being
## called directly from InteractionDetector.gd/NpcActor.gd/VendingMachine.gd.
func _on_favorite_toggle_requested(obj_id: String, label: String) -> void:
	var now_favorite := ProgressStore.toggle_favorite(level.id, obj_id, label)
	if now_favorite:
		EventBus.toast_requested.emit("⭐ Dodano do ulubionych: %s" % label)
	else:
		EventBus.toast_requested.emit("Usunięto z ulubionych: %s" % label)


func _on_item_collected(obj_id: String, _item_id: StringName) -> void:
	_collected_ids.append(obj_id)
	ProgressStore.record_item_collected(level.id, obj_id)
	print("[LevelRuntime] collected: ", obj_id)
	AudioService.play_pickup(SettingsStore.effective_volume())
	_pulse_player_camera()
	_update_status()


## Ported from PhaserGameCanvas.tsx onTalk: mark talked (idempotent — quests
## just check membership), grant the NPC's gift item once via
## Inventory.NPC_GIFTS/gift_obj_id (synthetic collected-id, same as the TS
## source; no pickup object exists on the map for gifts).
## `npc_id` — carried on EventBus's payload (see EventBus.gd, "Część 9") but
## unused here: the gift lookup below needs `npc.npc_id` from the resolved
## LevelObjectData anyway (that lookup also fetches `npc.message`, which
## isn't on the signal), so the parameter documents the payload without
## replacing the existing lookup.
func _on_npc_talked(obj_id: String, _npc_id: String) -> void:
	var already_talked := _talked.has(obj_id)
	if not already_talked:
		_talked.append(obj_id)
		ProgressStore.record_talked(level.id, obj_id)
	print("[LevelRuntime] talked: ", obj_id)

	var npc: LevelObjectData = null
	for obj in level.objects:
		if obj.id == obj_id:
			npc = obj
			break
	if npc == null:
		return

	if npc.message != "":
		_hud.set_message(npc.message)

	var gift: StringName = Inventory.NPC_GIFTS.get(npc.npc_id, &"")
	var gift_id := Inventory.gift_obj_id(obj_id)
	if gift != &"" and not _collected_ids.has(gift_id):
		_collected_ids.append(gift_id)
		ProgressStore.record_item_collected(level.id, gift_id)
		print("[LevelRuntime] gift received: ", gift)
		_pulse_player_camera()

	if not already_talked or gift != &"":
		_update_status()


## Camera punch on pickup (zoom 1.03x, 160ms) — see GAMEPLAY_BEHAVIOR.md,
## "Interakcje" -> "Item".
func _pulse_player_camera() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var camera = player.get_node_or_null("Camera2D")
	if camera != null:
		camera.pulse_zoom(1.03, 0.16)


func _on_goal_reached(obj_id: String) -> void:
	var goal: LevelObjectData = null
	for obj in level.objects:
		if obj.id == obj_id:
			goal = obj
			break
	if goal == null:
		return

	var inventory := Inventory.inventory_from_collected(level, _collected_ids)
	var unmet := []
	for item_id in goal.requires:
		var need: int = goal.requires[item_id]
		var have: int = inventory.get(item_id, 0)
		if have < need:
			unmet.append("%s x%d (masz %d)" % [item_id, need, have])

	if unmet.is_empty():
		_level_completed = true
		var elapsed := Time.get_ticks_msec() - _start_ticks_msec
		var next_id := _next_level_id()
		ProgressStore.record_level_completed(level.id, next_id, elapsed)
		ProgressStore.clear_checkpoint()
		print("[LevelRuntime] level completed: ", goal.message)
		AudioService.play_completion(SettingsStore.effective_volume())
		_hud.set_message(goal.message)
	else:
		var missing_text := ", ".join(unmet)
		print("[LevelRuntime] goal '%s' blocked, missing: %s" % [obj_id, missing_text])
		_hud.set_message("Jeszcze nie wszystko. Potrzeba: %s" % missing_text)
	_update_status()


## Levels are numbered "1".."6" in sequence (src/game/levels.ts order) — the
## next id is just +1, empty string past the last level. No LEVELS registry
## exists in Godot yet (LevelSelectMenu hardcodes its own list), so this
## mirrors `LEVELS[idx + 1]` from PhaserGameCanvas.tsx without needing one.
func _next_level_id() -> String:
	if not level.id.is_valid_int():
		return ""
	var next := level.id.to_int() + 1
	return str(next) if next <= 7 else ""


## rpg.md section 11 backlog ("Log/dziennik questów") — quest.id of every
## quest this LevelRuntime has already reported done, so the newly-done
## check below fires ProgressStore.record_quest_completed() exactly once per
## quest per level session, not on every ~10/s _update_status() tick while
## the quest stays done.
var _known_done_quest_ids: Array[String] = []


func _update_status() -> void:
	var inventory := Inventory.inventory_from_collected(level, _collected_ids)
	for item_id in _debug_bonus_inventory:
		inventory[item_id] = inventory.get(item_id, 0) + _debug_bonus_inventory[item_id]
	var snapshot := {
		"inventory": inventory,
		"talked": _talked,
		"level_completed": _level_completed,
		"collected": _collected_ids,
	}
	var statuses := QuestUtils.compute_quests(level, snapshot, _items)
	var completion: QuestCompletion = QuestUtils.quest_completion(statuses)
	print("[LevelRuntime] quests %d/%d" % [completion.done, completion.total])
	for status in statuses:
		if status.done and not _known_done_quest_ids.has(status.quest.id):
			_known_done_quest_ids.append(status.quest.id)
			ProgressStore.record_quest_completed(level.id, status.quest.id)
			EventBus.toast_requested.emit("Ukończono: %s" % status.quest.label)
	_hud.update_status(statuses, inventory, _items)
