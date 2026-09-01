class_name StreetEventSpawner
extends Node
## rpg.md section 11 backlog ("losowe wydarzenia uliczne"). Deliberately the
## smallest useful version: pure flavor toasts on a random timer, exactly the
## same "not wired into LevelBuilder's kind-switch yet" status as
## VendingMachine.gd had before its own integration step — a standalone node
## droppable into any level scene, not a new autoload (rule from god/godot2.md:
## autoloads used sparingly) and not a gameplay-affecting system.
##
## Uses EventBus.toast_requested (existing signal, read-only from here) rather
## than reaching into HUD directly — same decoupling rule as VendingMachine.gd.

const MIN_INTERVAL_SECONDS := 60.0
const MAX_INTERVAL_SECONDS := 180.0

## Luźne, nie-questowe zdarzenia uliczne — czysty flavor, jak
## AmbientPedestrian.gd's plotki, ale jako miejskie "coś się dzieje w tle"
## zamiast dialogu konkretnej postaci.
const EVENTS: Array[String] = [
	"W oddali słychać syreny.",
	"Ktoś zgubił drobne na chodniku, ale już ich nie widać.",
	"Uliczny grajek gra coś fałszywie na rogu.",
	"Przez chwilę pachnie świeżym chlebem z pobliskiej piekarni.",
	"Gołębie rozlatują się nagle bez wyraźnego powodu.",
]

var _timer: float = 0.0


func _ready() -> void:
	_roll_next_interval()


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_trigger_event()
		_roll_next_interval()


func _roll_next_interval() -> void:
	_timer = randf_range(MIN_INTERVAL_SECONDS, MAX_INTERVAL_SECONDS)


func _trigger_event() -> void:
	var text: String = EVENTS[randi() % EVENTS.size()]
	EventBus.toast_requested.emit(text)
