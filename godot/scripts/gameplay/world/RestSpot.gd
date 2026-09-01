class_name RestSpot
extends Area2D
## rpg.md backlog ("Tryb 'szybkiego dnia' — przyspieszenie czasu w
## bezpiecznym miejscu zamiast biernego czekania") — a placeable interactable
## (bench/hideout), duck-typed `interact(player)` like VendingMachine/
## ShortcutGate. Advances the game clock by `hours_to_advance` in one jump
## via TimeManager.advance_minutes() (already used by TransitStation for fast
## travel — reused here rather than a new time-skip mechanism) and fully
## restores energy via the same EventBus.energy_restore_requested VendingMachine
## uses, so LevelRuntime's existing exhaustion-clearing logic applies unchanged.
##
## No cooldown/once-per-day gate — deliberately simple ("prosty system" per
## the backlog wording), the player can rest again immediately if they want;
## the clock only ever moves forward, so there's no way to abuse this for
## anything but skipping time the player would otherwise spend idle.

@export var hours_to_advance: int = 4
@export var obj_id: String = ""


func _ready() -> void:
	var label: Label = $IconLabel
	label.text = "🛋️"


func interact(_player: Node) -> void:
	TimeManager.advance_minutes(hours_to_advance * TimeManager.MINUTES_PER_HOUR)
	EventBus.energy_restore_requested.emit(Difficulty.MAX_ENERGY)
	EventBus.toast_requested.emit("Odpoczęto — czas: %s" % TimeManager.time_string())


## rpg.md backlog ("Ulubione miejsca") — same optional obj_id/get_favorite_label()
## duck-type as VendingMachine/NpcActor; empty obj_id means "not favoritable".
func get_favorite_label() -> String:
	return "🛋️ Miejsce odpoczynku"
