class_name PoliceReactionSystem
extends Node
## rpg.md section 6/11 backlog ("Reputacja w dzielnicach" + "reakcje policji/
## reputacji"). EventBus.reputation_changed has existed since the economy
## round with no listener yet (its own header says exactly that — "add ahead
## of a planned but not-yet-built consumer"). This is that first consumer.
##
## Deliberately narrow: reacts only via toast (EventBus.toast_requested),
## no spawning/AI/gameplay consequence yet — reputation.gd's own comment
## documents "no fixed min/max", so thresholds here are just the first
## reasonable cut, not a balanced design. A standalone Node (not an
## autoload — same "used sparingly" rule as StreetEventSpawner.gd), one
## per zone/level scene that cares about police reacting to the player.

## Ordered by severity ascending (mildest/first-crossed reputation value
## first) — NOT numeric ascending. -15 is crossed while reputation is still
## dropping toward -30, so it must be index 0 (level "obserwują") and -30
## index 1 (level "poszukiwany"), even though -30 < -15 numerically.
const THRESHOLDS := [-15, -30]
const WARNING_TEXTS := [
	"Policja zaczyna Cię obserwować w tej dzielnicy.",
	"Jesteś poszukiwany! Policja aktywnie Cię szuka.",
]

@export var zone_id: String = ""

## Najwyższy próg (indeks w THRESHOLDS), o którym gracz już został
## ostrzeżony — zapobiega spamowaniem tym samym toastem przy każdym
## pojedynczym punkcie reputacji, ostrzega tylko przy przekroczeniu.
var _last_warned_level: int = -1


func _ready() -> void:
	EventBus.reputation_changed.connect(_on_reputation_changed)


func _on_reputation_changed(changed_zone_id: String, new_value: int) -> void:
	if zone_id != "" and changed_zone_id != zone_id:
		return
	var level := _level_for(new_value)
	if level > _last_warned_level:
		EventBus.toast_requested.emit(WARNING_TEXTS[level])
	_last_warned_level = level


## Zwraca -1 (brak ostrzeżenia) albo indeks najwyższego przekroczonego progu.
func _level_for(value: int) -> int:
	var level := -1
	for i in THRESHOLDS.size():
		if value <= THRESHOLDS[i]:
			level = i
	return level
