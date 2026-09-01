class_name TransitMenu
extends CanvasLayer
## rpg.md section 6 backlog ("Metro i szybka podróż") — plain animated
## Control panel, deliberately NOT a smartphone screen (user's explicit
## "bez systemu smartfona"). Pauses the SceneTree while open (this is the
## first thing in the project to do so — no PauseMenu exists yet per
## docs/ROADMAP.md's own audit — so `process_mode = PROCESS_MODE_ALWAYS`
## here and on the panel is what keeps this menu's own buttons/tween
## responsive while everything else freezes).
##
## Styled through edek_theme.tres like the rest of the project's UI
## (Buttons/PanelContainer get their look from the Theme automatically,
## no per-instance StyleBox here) with the same pop-in/pop-out tween shape
## as ToastManager.gd, for visual consistency across the session's new UI.

const ANIM_DURATION := 0.22
const POP_SCALE_FROM := 0.85

@onready var _panel: PanelContainer = $Panel
@onready var _title: Label = $Panel/VBox/Title
@onready var _list: VBoxContainer = $Panel/VBox/DestinationList

func open(station_name: String, destinations: Array[TransitDestination]) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_title.text = "Stacja: %s" % station_name
	_title.theme_type_variation = &"HeaderMedium"

	for destination in destinations:
		var btn := Button.new()
		var price := Difficulty.scaled_price(destination.cost, SettingsStore.difficulty)
		btn.text = "%s — %d zł, %d min" % [destination.display_name, price, destination.travel_minutes]
		btn.pressed.connect(_on_destination_selected.bind(destination))
		_list.add_child(btn)

	var cancel := Button.new()
	cancel.text = "Anuluj"
	cancel.pressed.connect(_close)
	_list.add_child(cancel)

	_panel.modulate.a = 0.0
	_panel.scale = Vector2(POP_SCALE_FROM, POP_SCALE_FROM)
	_panel.resized.connect(func() -> void: _panel.pivot_offset = _panel.size / 2.0, CONNECT_ONE_SHOT)

	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 1.0, ANIM_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_panel, "scale", Vector2.ONE, ANIM_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_destination_selected(destination: TransitDestination) -> void:
	if _try_purchase(destination):
		_close()
		SceneRouter.change_scene_to_file(destination.target_scene_path)

## Split out from _on_destination_selected() so the money/clock gating logic
## is testable without also triggering SceneRouter's real scene swap (which
## needs actual SceneTree/current_scene state a bare unit test doesn't have)
## — tests/economy/test_transit_station.gd calls this directly.
func _try_purchase(destination: TransitDestination) -> bool:
	var price := Difficulty.scaled_price(destination.cost, SettingsStore.difficulty)
	if ProgressStore.spend_money(price):
		TimeManager.advance_minutes(destination.travel_minutes)
		return true
	EventBus.toast_requested.emit("Za mało pieniędzy na bilet (%d zł)" % price)
	return false

func _close() -> void:
	get_tree().paused = false
	queue_free()
