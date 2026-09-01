class_name TransitStation
extends Area2D
## rpg.md section 6 backlog ("Metro i szybka podróż") — same
## InteractionDetector.gd `interact(player)` duck-typing as VendingMachine.gd
## and items/NPCs, no changes needed there.
##
## interact() opens TransitMenu.tscn (a plain Control panel, NOT a
## smartphone screen per the user's explicit "bez systemu smartfona") with
## this station's `destinations` (Array[TransitDestination]) as choices.
## Picking one spends money (ProgressStore), advances the clock
## (TimeManager.advance_minutes — added specifically with this consumer in
## mind, see its own header) and changes scene (SceneRouter) — same pattern
## as VendingMachine.gd asking EventBus/ProgressStore/TimeManager rather
## than reaching into gameplay directly.

const TransitMenuScene := preload("res://scenes/transit/TransitMenu.tscn")

@export var station_id: StringName
@export var display_name: String = "Przystanek"
@export var destinations: Array[TransitDestination] = []

func _ready() -> void:
	var label: Label = $IconLabel
	label.text = "🚉"

func interact(_player: Node) -> void:
	if destinations.is_empty():
		EventBus.toast_requested.emit("%s: brak połączeń" % display_name)
		return
	var menu := TransitMenuScene.instantiate() as TransitMenu
	get_tree().current_scene.add_child(menu)
	menu.open(display_name, destinations)
