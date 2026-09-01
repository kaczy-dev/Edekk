class_name VendingMachine
extends Area2D
## rpg.md section 6 backlog ("Ekonomia miejska", "Automaty i sklepy") —
## first concrete InteractionDetector consumer outside items/NPCs.
## `interact(player)` is duck-typed the same way ItemPickup/NpcActor already
## implement it — InteractionDetector.gd only checks `has_method("interact")`,
## nothing vending-machine-specific was needed there.
##
## Visual: emoji glyph (🥤), same house style as items/NPCs/goals per
## CLAUDE.md — "emoji-as-sprite... until Faza 1 art rework", not a
## regression, consistency with everything else currently in the world.
##
## NOT wired into LevelBuilder.gd's `kind` switch yet — this is a
## standalone, hand-placeable scene (see scenes/dev/TestEconomy.tscn) for
## this foundation pass. A `LevelObjectData.kind == "vending_machine"` case
## is the natural follow-up once a level actually wants one placed via data,
## same pattern as "enemy" (rpg.md section 5g) — not done here to keep this
## slice reviewable on its own.

@export var cost: int = 5
@export var energy_restored: float = 30.0
@export var item_label: String = "🥤 Cola"

## rpg.md backlog ("Ulubione miejsca") — optional identity for bookmarking a
## specific placed machine (empty on machines not meant to be favoritable,
## e.g. a one-off dev-scene instance with no stable id). Same "" == "not
## set" convention as LevelObjectData's own optional String exports.
@export var obj_id: String = ""

## Idle presentation: a slow bob + glow pulse on the emoji glyph, same
## "cheap juice on top of the emoji-rect placeholder" idea as the toast pop —
## does not touch DebugVisual (the placeholder rect itself stays put per
## CLAUDE.md's house style), only IconLabel animates.
const BOB_AMPLITUDE := 3.0
const BOB_DURATION := 1.4
const GLOW_MIN := 0.85
const GLOW_MAX := 1.15

## rpg.md section 11b backlog ("Sezonowe/dzienne promocje w automatach") —
## `TimeManager.current_day` (0=Monday..6=Sunday) as a deterministic seed:
## every machine in the world is on the same promo schedule (no per-machine
## RNG state to save), same day always means same promo, and it's readable
## at a glance ("promos on Wed/Sat") rather than feeling arbitrary.
const PROMO_DAYS := [2, 5] # Wednesday, Saturday
const PROMO_DISCOUNT := 0.8


func _is_promo_active() -> bool:
	return PROMO_DAYS.has(TimeManager.current_day)


func _ready() -> void:
	var label: Label = $IconLabel
	label.text = "🥤"
	label.pivot_offset = label.size / 2.0
	_start_idle_animation(label)
	$PromoBadge.visible = _is_promo_active()
	TimeManager.day_changed.connect(
		func(_d: int) -> void:
			$PromoBadge.visible = _is_promo_active(),
	)


func _start_idle_animation(label: Label) -> void:
	var base_y := label.position.y
	var idle := create_tween().set_loops()
	idle.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	idle.tween_property(label, "position:y", base_y - BOB_AMPLITUDE, BOB_DURATION)
	idle.parallel().tween_property(label, "modulate", Color(1, 1, 1, GLOW_MAX), BOB_DURATION)
	idle.tween_property(label, "position:y", base_y, BOB_DURATION)
	idle.parallel().tween_property(label, "modulate", Color(1, 1, 1, GLOW_MIN), BOB_DURATION)


func interact(_player: Node) -> void:
	_play_interact_pulse()
	# rpg.md section 11 backlog ("Panel trudności... ceny") — `cost` stays the
	# medium-difficulty baseline on the placed node; Difficulty.scaled_price()
	# applies the current difficulty's markup/discount at the point of sale.
	var price := Difficulty.scaled_price(cost, SettingsStore.difficulty)
	if _is_promo_active():
		price = maxi(0, roundi(price * PROMO_DISCOUNT))
	if ProgressStore.spend_money(price):
		EventBus.energy_restore_requested.emit(energy_restored)
		EventBus.item_purchased.emit(&"cola", price)
		EventBus.toast_requested.emit("Kupiono %s (-%d zł)" % [item_label, price])
	else:
		EventBus.toast_requested.emit("Za mało pieniędzy — potrzebujesz %d zł" % price)


## rpg.md backlog ("Ulubione miejsca") — see NpcActor.gd's get_favorite_label()
## for why this is a duck-typed method rather than a shared interface.
func get_favorite_label() -> String:
	return item_label


## A quick scale "punch" on the whole machine — separate Tween from the
## looping idle one above (both can safely run on the same node; Godot
## tweens property paths independently, they don't fight over "scale" vs
## "position:y"/"modulate").
func _play_interact_pulse() -> void:
	scale = Vector2.ONE
	var pulse := create_tween()
	pulse.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pulse.tween_property(self, "scale", Vector2(1.12, 1.12), 0.1)
	pulse.tween_property(self, "scale", Vector2.ONE, 0.2)
