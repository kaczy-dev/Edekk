class_name NightPatrolChallenge
extends Node
## rpg.md backlog ("Tryb nocny/patrol — cel: przetrwać/dotrzeć gdzieś tylko
## nocą (niebezpieczniej). Fundament już istnieje: TimeManager.is_night(),
## wrogowie już zróżnicowani (thug/bandit)") — a placeable, standalone Node
## (not an autoload, "used sparingly" rule from god/godot2.md), same shape
## as StreetEventSpawner.gd/PoliceReactionSystem.gd: drop into any level
## scene, reads TimeManager, reacts via EventBus/ProgressStore only.
##
## Deliberately reward-only, not a hard fail/game-over: this codebase has no
## player-death/respawn handling at all yet (checked — HealthComponent.died
## on the player only relays EventBus.player_damaged for the HUD, nothing
## else consumes it), so a real "die at night and lose the patrol" condition
## would need inventing that system first. Pairing this with
## StreetAmbushSpawner.gd (section 22, gated the same TimeManager.is_night()
## way) already makes the night itself the actual danger — this component
## just recognizes "you were here from dusk to dawn" and pays out once.

@export var patrol_id: String = ""
@export var reward_money: int = 100
@export var reputation_zone_id: String = ""
@export var reward_reputation: int = 10

var _was_night: bool = false


func _ready() -> void:
	_was_night = TimeManager.is_night()
	TimeManager.hour_changed.connect(_on_hour_changed)


func _on_hour_changed(_hour: int) -> void:
	var now_night := TimeManager.is_night()
	if _was_night and not now_night:
		_complete()
	_was_night = now_night


func _complete() -> void:
	if ProgressStore.is_night_patrol_completed(patrol_id):
		return
	ProgressStore.complete_night_patrol(patrol_id)
	ProgressStore.add_money(reward_money)
	if not reputation_zone_id.is_empty():
		ProgressStore.add_reputation(reputation_zone_id, reward_reputation)
	EventBus.toast_requested.emit("Przetrwałeś noc! (+%d zł)" % reward_money)
