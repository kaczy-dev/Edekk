class_name AmbientPedestrian
extends CharacterBody2D
## rpg.md section 6 backlog ("Ruch uliczny / ambient AI") — decorative city
## life, not an interactable/quest-relevant NPC (see NpcActor.gd for that;
## this is deliberately a separate, simpler class rather than adding
## "wander" as a third patrol mode there — NpcActor's patrol is a fixed
## back-and-forth line tied to quest-relevant NPCs, this is aimless
## background wandering with no interact()).
##
## Simple two-state FSM: IDLE (stand for a random few seconds) <-> WALK
## (walk to a random point within wander_radius of spawn, then go back to
## IDLE). No NavigationAgent2D — same "straight-line is the right amount of
## complexity for now" reasoning as EnemyChaseState.gd; docs/ROADMAP.md
## point 20 (real navigation) covers upgrading this later if it's ever
## needed for both.
##
## Visual: emoji glyph, same house style as items/NPCs/vending machines
## (CLAUDE.md — emoji-as-sprite until Faza 1 art rework, not a regression).

enum State {
	IDLE,
	WALK,
}

@export var wander_radius: float = 100.0
@export var move_speed: float = 40.0
@export var min_idle_seconds: float = 2.0
@export var max_idle_seconds: float = 5.0
@export var icon: String = "🚶"
## Szansa (0-1) na wypowiedzenie plotki przy każdym wejściu w IDLE — nie
## każde zatrzymanie, żeby miasto nie skrzeczało bez przerwy.
@export var gossip_chance: float = 0.35
@export var gossip_display_seconds: float = 3.5

const ARRIVAL_THRESHOLD := 4.0

## Luźne, niezwiązane z questami plotki — czysty flavor, sekcja 11 backlogu
## rpg.md ("plotki miejskie"). Celowo bez logiki warunkowej (reputacja/pora
## dnia) w tej rundzie — to udekorowanie miasta, nie system informacyjny.
const GOSSIP_LINES: Array[String] = [
	"Podobno w metrze znowu coś śmierdzi...",
	"Słyszałeś o tej bójce koło automatu?",
	"Ceny w tym mieście to jakiś żart.",
	"Ktoś mówił, że w nocy lepiej tu nie chodzić.",
	"Muszę kupić colę, ale to za drogie...",
	"Nowy w mieście? Trzymaj się głównych ulic.",
]

var state: State = State.IDLE
var _timer: float = 0.0
var _target: Vector2
var _origin: Vector2
var _gossip_label: Label


func _ready() -> void:
	_origin = global_position
	var label: Label = $IconLabel
	label.text = icon
	_gossip_label = $GossipLabel
	_enter_idle()


func _enter_idle() -> void:
	state = State.IDLE
	_timer = randf_range(min_idle_seconds, max_idle_seconds)
	if randf() < gossip_chance:
		_say_gossip()


func _say_gossip() -> void:
	_gossip_label.text = GOSSIP_LINES[randi() % GOSSIP_LINES.size()]
	var tween := create_tween()
	tween.tween_property(_gossip_label, "modulate:a", 1.0, 0.25)
	tween.tween_interval(gossip_display_seconds)
	tween.tween_property(_gossip_label, "modulate:a", 0.0, 0.5)


## Uniform point inside the wander circle (not a square — sqrt() on the
## radius fraction avoids the classic bug where naively picking a random
## radius clusters points toward the center; area scales with r², so the
## radius itself must be sqrt-distributed for a uniform circular spread).
func _enter_walk() -> void:
	state = State.WALK
	var angle := randf_range(0.0, TAU)
	var radius := wander_radius * sqrt(randf())
	_target = _origin + Vector2.RIGHT.rotated(angle) * radius


func _physics_process(delta: float) -> void:
	match state:
		State.IDLE:
			velocity = Vector2.ZERO
			_timer -= delta
			if _timer <= 0.0:
				_enter_walk()
		State.WALK:
			var to_target := _target - global_position
			if to_target.length() < ARRIVAL_THRESHOLD:
				_enter_idle()
			else:
				velocity = to_target.normalized() * move_speed
	move_and_slide()
