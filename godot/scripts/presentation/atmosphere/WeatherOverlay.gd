class_name WeatherOverlay
extends CanvasLayer
## rpg.md section 11 backlog ("pogoda niezależna od cyklu dobowego"). Deliberately
## SEPARATE state machine from DayNightOverlay.gd — that one is a pure function of
## TimeManager's hour; this one is an independent random cycle (rain can hit at
## noon, a clear night is just as likely as a rainy one). Composes safely with
## DayNightOverlay the same way that one composes with AtmosphereFX.gd: its own
## alpha-blended ColorRect on its own layer, nothing scene-tree-global.

enum State {
	CLEAR,
	RAIN,
	FOG,
}

const RAIN_COLOR := Color(0.15, 0.2, 0.35, 0.35)
const FOG_COLOR := Color(0.6, 0.6, 0.65, 0.3)
const CLEAR_COLOR := Color(0.15, 0.2, 0.35, 0.0)

const MIN_STATE_SECONDS := 45.0
const MAX_STATE_SECONDS := 150.0
const TRANSITION_SECONDS := 4.0

@onready var _rect: ColorRect = $ColorRect
@onready var _rain_particles: GPUParticles2D = $RainParticles

var state: State = State.CLEAR
var _timer: float = 0.0


func _ready() -> void:
	_pick_next_state()
	_apply_state(true)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_pick_next_state()
		_apply_state(false)


func _pick_next_state() -> void:
	_timer = randf_range(MIN_STATE_SECONDS, MAX_STATE_SECONDS)
	# Clear is deliberately weighted heaviest so the effect stays an accent,
	# not a constant filter over the whole city.
	var roll := randf()
	if roll < 0.55:
		state = State.CLEAR
	elif roll < 0.8:
		state = State.RAIN
	else:
		state = State.FOG


func _apply_state(instant: bool) -> void:
	var target_color := _color_for(state)
	if instant:
		_rect.color = target_color
	else:
		var tween := create_tween()
		tween.tween_property(_rect, "color", target_color, TRANSITION_SECONDS)
	_rain_particles.emitting = state == State.RAIN


func _color_for(s: State) -> Color:
	match s:
		State.RAIN:
			return RAIN_COLOR
		State.FOG:
			return FOG_COLOR
		_:
			return CLEAR_COLOR
