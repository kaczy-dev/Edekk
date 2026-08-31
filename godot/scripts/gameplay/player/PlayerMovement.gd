extends CharacterBody2D
## Player movement — ported from src/game/phaser/LevelScene.ts (see
## docs/migration/GAMEPLAY_BEHAVIOR.md, section "Ruch podstawowy" / "Sprint"
## / "Hop (Space)" / "Kamera").
##
## Scope of this slice: walk/sprint speed (now energy-gated via `can_sprint`,
## driven by LevelRuntime/Difficulty.gd), asymmetric accel/friction + sprint
## drift, hop dispatch (velocity write owned by PlayerHopState — see
## PlayerStateMachine.gd), Arcade-Physics-equivalent collision via
## move_and_slide(), camera shake on hop landing / hard wall collision.
## Squash/stretch, walk-cycle animation, lean and sprint ghost-trail moved
## to PlayerVisuals.gd (branch migration/player-physics, Faza 0 point 2 of
## docs/ROADMAP.md — this file had grown to 262 lines covering locomotion
## AND every visual reaction at once). NOT yet ported:
## - reducedMotion skipping shake/squash/lean/ghost-trail — Settings system
##   has no consumer for this yet (SettingsStore exists, but no UI toggle)
##
## `sprintMode` "toggle" deliberately NOT wired to the keyboard here — traced
## through the TS source (`LevelScene.ts` + `PhaserGameCanvas.tsx`) and
## confirmed `sprintToggled` is only ever set from an on-screen touch button
## in the HTML overlay; desktop keyboard Shift is "hold" in Phaser
## regardless of the `sprintMode` setting. Since Godot has no touch UI yet
## either, there is nothing to actually port for keyboard input — wiring a
## keyboard-driven toggle would invent behaviour the source never had.
## `SettingsStore.sprint_mode` is still persisted for when touch controls
## eventually exist.

const WALK_SPEED := 230.0
const RUN_SPEED := 380.0
const ACCELERATION := 2200.0
const FRICTION := 1300.0

## Below this speed, bumping a wall doesn't shake the camera — matches the
## Phaser source's "at speed > 40" condition for the collision squash/shake.
const COLLISION_SHAKE_MIN_SPEED := 40.0
const COLLISION_SHAKE_DURATION := 0.07
const COLLISION_SHAKE_AMPLITUDE_PX := 3.0
const HOP_LAND_SHAKE_DURATION := 0.06
const HOP_LAND_SHAKE_AMPLITUDE_PX := 2.0

@onready var _hop: PlayerHop = $Hop
@onready var _sprite: AnimatedSprite2D = $Sprite2D
@onready var _camera: CameraFX = $Camera2D
@onready var _paw_dust: CPUParticles2D = $PawDustParticles
@onready var _status: StatusEffectComponent = $StatusEffects
@onready var _state_machine: PlayerStateMachine = $StateMachine
@onready var _visuals: PlayerVisuals = $Visuals

var _was_colliding := false

## --- Sprint drift (ground-locomotion, stays here — lean/ghost-trail/anim
## moved to PlayerVisuals.gd, see file header) --------------------------
## 1:1 constant from LevelScene.ts's "Juicy turning / drift" section.
const DRIFT_TURN_ANGLE := PI / 2.0 # radians — sprint turns sharper than this drift
const DRIFT_DURATION := 0.14 # seconds (TS: DRIFT_MS = 140)

var _drift_remaining := 0.0
var _drift_velocity := Vector2.ZERO

## Set by LevelRuntime each frame from its Energy tracking
## (energy >= Difficulty min_sprint_energy) — 1:1 with the TS source's
## `energy < DIFFICULTIES[difficulty].minSprintEnergy` sprint-input guard.
## Defaults true so the player still sprints normally in scenes with no
## LevelRuntime driving it (e.g. TestLevel.tscn).
var can_sprint := true

## True when actually moving under sprint input this frame — read by
## LevelRuntime to drain Energy. Distinct from `Input.is_action_pressed
## ("sprint")` because standing still while holding Shift doesn't drain (see
## Phaser source's `isMoving` guard on the energy accumulator).
var is_sprinting := false
var is_moving := false

func _ready() -> void:
	_visuals.setup(_sprite, _paw_dust, get_parent())
	_hop.hop_started.connect(_visuals.on_hop_started)
	_hop.hop_landed.connect(_visuals.on_hop_landed)
	_hop.hop_landed.connect(_on_hop_landed_shake)
	_state_machine.setup(self, _hop)

func _physics_process(delta: float) -> void:
	# get_vector() normalizes diagonals to length 1, matching the Phaser
	# LevelScene input handling (diagonal movement is not faster).
	# Część 11: paralysis (StatusEffectComponent) zeroes input entirely,
	# including hop — no current consumer applies this effect on any ported
	# level, but the read is unconditional so PlayerMovement never needs to
	# know whether anything is actually using it.
	var input_dir := Vector2.ZERO if _status.paralyzed else Input.get_vector("move_left", "move_right", "move_up", "move_down")

	var hop_velocity: Variant = null if _status.paralyzed else _hop.update(delta, input_dir)
	_sprite.position.y = -_hop.arc_progress() * PlayerHop.ARC_HEIGHT

	var pre_slide_speed := velocity.length()

	is_moving = input_dir != Vector2.ZERO
	is_sprinting = can_sprint and Input.is_action_pressed("sprint") and is_moving

	if hop_velocity == null:
		var sprinting := is_sprinting
		var target_speed := (RUN_SPEED if sprinting else WALK_SPEED) * _status.speed_multiplier
		var target_velocity := input_dir * target_speed

		# Drift: carving a sharp turn at speed keeps some of the previous
		# heading for a beat instead of snapping the new direction on
		# instantly — a slide through the corner rather than a pivot.
		if _drift_remaining > 0.0:
			var drift_t := clampf(_drift_remaining / DRIFT_DURATION, 0.0, 1.0)
			target_velocity = target_velocity.lerp(_drift_velocity, drift_t * 0.6)
			_drift_remaining -= delta
		if is_moving and sprinting:
			var new_angle := input_dir.angle()
			# Reads PlayerVisuals.last_facing_angle: the *velocity*-direction
			# angle it wrote last frame — see that file's field comment for
			# why drift and lean deliberately share this one value.
			var turn_delta := wrapf(new_angle - _visuals.last_facing_angle, -PI, PI)
			if absf(turn_delta) > DRIFT_TURN_ANGLE and velocity.length() > WALK_SPEED:
				_drift_remaining = DRIFT_DURATION
				_drift_velocity = velocity

		if input_dir != Vector2.ZERO:
			velocity = velocity.move_toward(target_velocity, ACCELERATION * delta)
		else:
			# Friction is weaker than acceleration on purpose — "the cat slides to
			# a stop, it doesn't brake like a robot" (comment from the Phaser source).
			velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)

	# Classifies this frame (ground velocity above, or hop_velocity here) and
	# dispatches to the active PlayerState. For HOP specifically,
	# PlayerHopState.physics_update() now OWNS the velocity write (see
	# PlayerHopState.gd) — this is the "FSM drives physics" step from
	# plan31-08.md's "principal lead" follow-up #4, deliberately scoped to
	# just the Hop state (the most isolated one, per the user's own
	# recommendation) rather than also moving Walk/Sprint/Idle's
	# accel/friction/drift, which stays here for now. Must run after the
	# ground-velocity branch above (classification needs this frame's
	# velocity for the Walk/Sprint/Idle threshold) but before move_and_slide()
	# (HOP needs its velocity applied before sliding, not after — this is an
	# intentional reordering from before this change, when HOP's velocity was
	# written inline above and move_and_slide() ran regardless of state).
	_state_machine.physics_update(delta, hop_velocity)

	move_and_slide()
	_visuals.update_animation(delta, velocity, is_sprinting, RUN_SPEED)

	var is_colliding := get_slide_collision_count() > 0
	if is_colliding and not _was_colliding and pre_slide_speed > COLLISION_SHAKE_MIN_SPEED:
		_camera.shake(COLLISION_SHAKE_DURATION, COLLISION_SHAKE_AMPLITUDE_PX)
	_was_colliding = is_colliding

## Camera-only half of hop landing — the sprite-visual half (squash tween,
## paw dust) is PlayerVisuals.on_hop_landed(), connected separately in
## _ready(). Split rather than one shared handler so each listener owns
## exactly the node it touches (PlayerMovement owns Camera2D, PlayerVisuals
## owns Sprite2D/PawDustParticles) — no handler reaches across into a node
## another component is responsible for.
func _on_hop_landed_shake() -> void:
	_camera.shake(HOP_LAND_SHAKE_DURATION, HOP_LAND_SHAKE_AMPLITUDE_PX)
