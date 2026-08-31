extends CharacterBody2D
## Player movement — ported from src/game/phaser/LevelScene.ts (see
## docs/migration/GAMEPLAY_BEHAVIOR.md, section "Ruch podstawowy" / "Sprint"
## / "Hop (Space)" / "Kamera").
##
## Scope of this slice: walk/sprint speed (now energy-gated via `can_sprint`,
## driven by LevelRuntime/Difficulty.gd), asymmetric accel/friction, hop,
## Arcade-Physics-equivalent collision via move_and_slide(), camera shake on
## hop landing / hard wall collision, hop squash/stretch + paw dust (see
## _on_hop_started()/_on_hop_landed()), and the turning polish layer — lean,
## sprint drift, ghost-trail, speed-scaled animation (see "Ported from
## LevelScene.ts update()" below _update_animation()). NOT yet ported:
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

## The sprite's authored display scale (set in Player.tscn to shrink the
## 896x1200 sheet frame down to ~64px on-screen) — squash/stretch tweens
## multiply this, they don't replace it, otherwise the cat would snap to a
## wrong on-screen size for the duration of the tween.
var _sprite_base_scale: Vector2
var _squash_tween: Tween

## Minimum speed to count as "moving" for animation purposes — avoids the
## walk cycle twitching on/off from friction's asymptotic approach to zero.
const ANIM_MOVE_THRESHOLD := 5.0

var _was_colliding := false

## --- Turning polish: lean, sprint drift, ghost-trail ------------------
## 1:1 constants from LevelScene.ts's "Juicy turning / drift" section.
const TURN_LEAN_MAX := 0.16 # radians
const DRIFT_TURN_ANGLE := PI / 2.0 # radians — sprint turns sharper than this drift
const DRIFT_DURATION := 0.14 # seconds (TS: DRIFT_MS = 140)
const GHOST_INTERVAL := 0.045 # seconds (TS: GHOST_INTERVAL = 45ms)
const GHOST_TINT := Color(0.561, 0.816, 1.0, 0.32) # 0x8fd0ff @ alpha 0.32
const GHOST_FADE_DURATION := 0.22
const GHOST_SHRINK_TO := 0.85

## Updated once per frame, after move_and_slide() — drift compares this
## frame's *input*-direction turn against last frame's *velocity*-direction
## angle (yes, different vectors; this is what the TS source does — see
## _physics_process()'s drift block vs. _update_animation()'s lean block).
var _last_facing_angle := PI / 2.0 # pointing "down", matches TS default
var _drift_remaining := 0.0
var _drift_velocity := Vector2.ZERO
var _ghost_accum := 0.0

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
	_sprite_base_scale = _sprite.scale
	_hop.hop_started.connect(_on_hop_started)
	_hop.hop_landed.connect(_on_hop_landed)
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
			var turn_delta := wrapf(new_angle - _last_facing_angle, -PI, PI)
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
	_update_animation(delta)

	var is_colliding := get_slide_collision_count() > 0
	if is_colliding and not _was_colliding and pre_slide_speed > COLLISION_SHAKE_MIN_SPEED:
		_camera.shake(COLLISION_SHAKE_DURATION, COLLISION_SHAKE_AMPLITUDE_PX)
	_was_colliding = is_colliding

## Squash-then-stretch, driven by AnimatedSprite2D.scale only — never
## CharacterBody2D.scale, which would also scale CollisionShape2D and break
## collision. Ported from plan31-08.md "Część 7" with one deliberate
## simplification: the spec describes a squash that happens *before* the cat
## physically leaves the ground (anticipation), but PlayerHop.gd's timing
## (jump-buffer/coyote-time tested and TESTED-confirmed in the editor) has no
## such pre-liftoff window — hop_started already means "velocity override is
## active this frame". Squashing instantaneously at hop_started and then
## tweening into the stretch over the flight reads the same to the eye
## without touching PlayerHop's timing logic.
const SQUASH_ANTICIPATION := Vector2(1.2, 0.8)
const SQUASH_STRETCH_FLIGHT := Vector2(0.8, 1.3)
const SQUASH_LANDING := Vector2(1.3, 0.7)
const SQUASH_LANDING_RECOVER_DURATION := 0.15

func _on_hop_started(_direction: Vector2) -> void:
	_paw_dust.restart()
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()
	_sprite.scale = _sprite_base_scale * SQUASH_ANTICIPATION
	_squash_tween = create_tween()
	_squash_tween.tween_property(_sprite, "scale", _sprite_base_scale * SQUASH_STRETCH_FLIGHT, PlayerHop.DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_hop_landed() -> void:
	_camera.shake(HOP_LAND_SHAKE_DURATION, HOP_LAND_SHAKE_AMPLITUDE_PX)
	_paw_dust.restart()
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()
	_sprite.scale = _sprite_base_scale * SQUASH_LANDING
	_squash_tween = create_tween()
	_squash_tween.tween_property(_sprite, "scale", _sprite_base_scale, SQUASH_LANDING_RECOVER_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## Ported from LevelScene.ts update(): direction picked from the dominant
## velocity axis (not "last key pressed"), animation frozen on its current
## frame while stationary rather than reset to an idle pose — matches
## `anims.stop()` in the source, which halts without resetting the frame.
## Also drives the lean/ghost-trail/speed-scaled-animation polish layer,
## all still keyed off this frame's post-move_and_slide() velocity.
func _update_animation(delta: float) -> void:
	if velocity.length() < ANIM_MOVE_THRESHOLD:
		_sprite.stop()
		_lean_toward(0.0, delta, false)
		return
	var dir := "right" if velocity.x > 0 else "left"
	if absf(velocity.x) <= absf(velocity.y):
		dir = "down" if velocity.y > 0 else "up"
	var anim := "walk-%s" % dir
	if _sprite.animation != anim:
		_sprite.play(anim)
	elif not _sprite.is_playing():
		_sprite.play(anim)

	# Speed-scaled animation tempo: idle-ish shuffle at low speed, full-tempo
	# cycle at a sprint, instead of one fixed rate. speed_ratio also drives
	# lean strength below.
	var speed_ratio := minf(1.0, velocity.length() / RUN_SPEED)
	_sprite.speed_scale = 0.55 + speed_ratio * 0.85

	# Lean: carve into turns at speed, using the *velocity* direction (not
	# input direction — that's the drift block above, a deliberately
	# different vector, matching the TS source).
	var angle := velocity.angle()
	var turn_delta := wrapf(angle - _last_facing_angle, -PI, PI)
	_last_facing_angle = angle
	var lean := clampf(turn_delta * 2.2, -TURN_LEAN_MAX, TURN_LEAN_MAX) * speed_ratio
	_lean_toward(lean, delta, true)

	# Sprint ghost trail: cheap "motion blur" via short-lived faded copies of
	# the current frame, spawned at a fixed cadence rather than every frame.
	if is_sprinting:
		_ghost_accum += delta
		if _ghost_accum >= GHOST_INTERVAL:
			_ghost_accum = 0.0
			_spawn_ghost()
	else:
		_ghost_accum = 0.0

## `approaching` picks which of the TS source's two lerp rates applies
## (0.35 while actively leaning into a turn, 0.20 while relaxing back to
## 0) — ported as delta-scaled exponential smoothing rather than a flat
## per-tick factor, since Część 13 raised physics_ticks_per_second to 120;
## applying the original flat factor per tick at 2x the tick rate would
## make the lean converge twice as fast in real time as it did at Phaser's
## ~60fps.
func _lean_toward(target: float, delta: float, approaching: bool) -> void:
	var rate_per_60fps := 0.35 if approaching else 0.2
	var t := clampf(rate_per_60fps * delta * 60.0, 0.0, 1.0)
	_sprite.rotation = lerpf(_sprite.rotation, target, t)

func _spawn_ghost() -> void:
	var frame_texture := _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
	if frame_texture == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = frame_texture
	ghost.global_transform = _sprite.global_transform
	ghost.modulate = GHOST_TINT
	ghost.z_index = _sprite.z_index - 1
	get_parent().add_child(ghost)

	var tween := ghost.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ghost, "modulate:a", 0.0, GHOST_FADE_DURATION)
	tween.tween_property(ghost, "scale", ghost.scale * GHOST_SHRINK_TO, GHOST_FADE_DURATION)
	tween.chain().tween_callback(ghost.queue_free)
