class_name PlayerVisuals
extends Node
## Purely visual reaction layer for the player — squash/stretch on hop,
## walk-cycle direction/speed-scale, turning lean, sprint ghost-trail.
##
## Split out of PlayerMovement.gd (branch migration/player-physics, Faza 0
## point 2 of docs/ROADMAP.md — "PlayerMovement.gd rozrósł się do 262 linii,
## trzyma ruch, drift, lean, squash i ghost naraz"). This file owns none of
## PlayerMovement's ground-locomotion physics (accel/friction/drift stay
## there — they read/write `velocity`, this component never does) or
## PlayerHop's timing (buffer/coyote/cooldown stay in PlayerHop.gd,
## untouched). Zero behavior change from the pre-split code — every
## constant, formula and comment below is a verbatim move, not a rewrite.
##
## Setup by PlayerMovement._ready() (same pattern as PlayerStateMachine.
## setup()) rather than @onready-resolving siblings itself, since this node
## has no reliable path back to Player's other children without a parent
## reference — Player.tscn owns the wiring, this component just receives it.

const SQUASH_ANTICIPATION := Vector2(1.2, 0.8)
const SQUASH_STRETCH_FLIGHT := Vector2(0.8, 1.3)
const SQUASH_LANDING := Vector2(1.3, 0.7)
const SQUASH_LANDING_RECOVER_DURATION := 0.15

## feature/rpg-combat (rpg.md): the cat has no attack animation (see
## PlayerAttackState.gd's header). First cut (squash alone) read as
## "straszne" on manual playtest — a static pose with nothing selling the
## idea of reaching toward something. Rebuilt as three simultaneous cues:
## a forward lunge of the sprite (not CharacterBody2D — collision must not
## move), a sharper squash, and a real slash VFX sprite in the facing
## direction (see _spawn_slash()).
const SQUASH_ATTACK := Vector2(1.25, 0.78)
const SQUASH_ATTACK_RECOVER_DURATION := 0.18
const LUNGE_DISTANCE := 14.0
const LUNGE_OUT_DURATION := 0.08
const LUNGE_RECOVER_DURATION := 0.16

const SLASH_TEXTURE := preload("res://assets/assety/brackeys_vfx_bundle/particles/alpha/slash_01_a.png")
const SLASH_OFFSET := 26.0 # px in front of the cat
const SLASH_SCALE := 0.12 # source is 512x512 — reads as a ~60px swipe
const SLASH_FADE_DURATION := 0.22

## Minimum speed to count as "moving" for animation purposes — avoids the
## walk cycle twitching on/off from friction's asymptotic approach to zero.
const ANIM_MOVE_THRESHOLD := 5.0

## 1:1 constants from LevelScene.ts's "Juicy turning / drift" section.
const TURN_LEAN_MAX := 0.16 # radians
const GHOST_INTERVAL := 0.045 # seconds (TS: GHOST_INTERVAL = 45ms)
const GHOST_TINT := Color(0.561, 0.816, 1.0, 0.32) # 0x8fd0ff @ alpha 0.32
const GHOST_FADE_DURATION := 0.22
const GHOST_SHRINK_TO := 0.85

var _sprite: AnimatedSprite2D
var _paw_dust: CPUParticles2D
var _ghost_parent: Node

## The sprite's authored display scale (set in Player.tscn to shrink the
## 896x1200 sheet frame down to ~64px on-screen) — squash/stretch tweens
## multiply this, they don't replace it, otherwise the cat would snap to a
## wrong on-screen size for the duration of the tween.
var _sprite_base_scale: Vector2
var _squash_tween: Tween

## PUBLIC, not `_`-prefixed: PlayerMovement's sprint-drift block reads this
## every frame (drift compares its own *input*-direction turn against the
## *velocity*-direction angle lean wrote last frame — two deliberately
## different vectors, matching the TS source's "Juicy turning / drift"
## section). This is the ONLY piece of state shared back to PlayerMovement;
## everything else in this file is local to the visual layer.
var last_facing_angle := PI / 2.0 # pointing "down", matches TS default
var _ghost_accum := 0.0

## Called once from PlayerMovement._ready(). `ghost_parent` is Player's own
## parent (the level's world Node2D) — ghosts are siblings of Player, not
## siblings of Sprite2D, matching the original `get_parent().add_child()`
## call site (which ran from a script attached to Player, one level up from
## here).
func setup(sprite: AnimatedSprite2D, paw_dust: CPUParticles2D, ghost_parent: Node) -> void:
	_sprite = sprite
	_paw_dust = paw_dust
	_ghost_parent = ghost_parent
	_sprite_base_scale = _sprite.scale

## Ported from plan31-08.md "Część 7" with one deliberate simplification:
## the spec describes a squash that happens *before* the cat physically
## leaves the ground (anticipation), but PlayerHop.gd's timing (jump-buffer/
## coyote-time tested and TESTED-confirmed in the editor) has no such
## pre-liftoff window — hop_started already means "velocity override is
## active this frame". Squashing instantaneously at hop_started and then
## tweening into the stretch over the flight reads the same to the eye
## without touching PlayerHop's timing logic.
func on_hop_started(_direction: Vector2) -> void:
	_paw_dust.restart()
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()
	_sprite.scale = _sprite_base_scale * SQUASH_ANTICIPATION
	_squash_tween = create_tween()
	_squash_tween.tween_property(_sprite, "scale", _sprite_base_scale * SQUASH_STRETCH_FLIGHT, PlayerHop.DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## Camera shake on landing stays in PlayerMovement (it already owns the
## Camera2D reference and the collision-shake constants — one owner for
## "things that shake the camera"). This handles only the sprite-visual
## half of landing.
func on_hop_landed() -> void:
	_paw_dust.restart()
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()
	_sprite.scale = _sprite_base_scale * SQUASH_LANDING
	_squash_tween = create_tween()
	_squash_tween.tween_property(_sprite, "scale", _sprite_base_scale, SQUASH_LANDING_RECOVER_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## feature/rpg-combat: squash + a forward lunge of the sprite (offset only —
## CharacterBody2D.position/collision never move, this is purely cosmetic,
## same principle as the hop's arc offset) + a slash VFX in the direction
## the cat is currently facing (Vector2.RIGHT.rotated(last_facing_angle) —
## the same angle drift/lean already read off velocity, see that field's
## comment above).
func on_attack_started() -> void:
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()
	_sprite.scale = _sprite_base_scale * SQUASH_ATTACK

	var direction := Vector2.RIGHT.rotated(last_facing_angle)

	# Lunge is X-only, deliberately: PlayerMovement._physics_process() writes
	# _sprite.position.y unconditionally every physics frame (the hop arc
	# offset — 0 outside a hop), which would fight a Y-axis tween here and
	# erase it within one frame. A pure-X lunge is weaker for a straight
	# up/down attack but never silently gets cancelled, unlike a Vector2 one
	# would have (found by tracing that line, not by seeing it fail).
	_squash_tween = create_tween()
	_squash_tween.set_parallel(true)
	_squash_tween.tween_property(_sprite, "scale", _sprite_base_scale, SQUASH_ATTACK_RECOVER_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_squash_tween.tween_property(_sprite, "position:x", direction.x * LUNGE_DISTANCE, LUNGE_OUT_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_squash_tween.chain().tween_property(_sprite, "position:x", 0.0, LUNGE_RECOVER_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	_spawn_slash(direction)

## One-off Sprite2D + tween, not pooled through VfxSpawner — attacks are
## gated by PlayerAttack.COOLDOWN (0.25s), an order of magnitude less
## frequent than the ghost-trail's 45ms interval that docs/ROADMAP.md's
## rule-7 audit actually flagged as a problem. Matches this project's
## existing tolerance for _spawn_ghost() below, not a new anti-pattern.
func _spawn_slash(direction: Vector2) -> void:
	var slash := Sprite2D.new()
	slash.texture = SLASH_TEXTURE
	slash.global_position = _sprite.get_parent().global_position + direction * SLASH_OFFSET
	slash.rotation = direction.angle() + PI / 2.0 # texture's crescent opens "up" by default
	slash.scale = Vector2(SLASH_SCALE, SLASH_SCALE) * (Vector2(-1, 1) if direction.x < 0 else Vector2.ONE)
	slash.modulate = Color(1.0, 1.0, 1.0, 0.9)
	slash.z_index = _sprite.z_index + 1
	_ghost_parent.add_child(slash)

	var tween := slash.create_tween()
	tween.set_parallel(true)
	tween.tween_property(slash, "modulate:a", 0.0, SLASH_FADE_DURATION)
	tween.tween_property(slash, "scale", slash.scale * 1.4, SLASH_FADE_DURATION)
	tween.chain().tween_callback(slash.queue_free)

## Ported from LevelScene.ts update(): direction picked from the dominant
## velocity axis (not "last key pressed"), animation frozen on its current
## frame while stationary rather than reset to an idle pose — matches
## `anims.stop()` in the source, which halts without resetting the frame.
## Also drives the lean/ghost-trail/speed-scaled-animation polish layer.
## `velocity`/`is_sprinting`/`run_speed` are read-only inputs from
## PlayerMovement — this component never touches CharacterBody2D.velocity.
func update_animation(delta: float, velocity: Vector2, is_sprinting: bool, run_speed: float) -> void:
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
	var speed_ratio := minf(1.0, velocity.length() / run_speed)
	_sprite.speed_scale = 0.55 + speed_ratio * 0.85

	# Lean: carve into turns at speed, using the *velocity* direction (not
	# input direction — that's PlayerMovement's drift block, a deliberately
	# different vector, matching the TS source).
	var angle := velocity.angle()
	var turn_delta := wrapf(angle - last_facing_angle, -PI, PI)
	last_facing_angle = angle
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

## TODO (docs/ROADMAP.md sekcja "Audyt zgodności z zasadami 4-7", zasada 7):
## this allocates a new Sprite2D every GHOST_INTERVAL (~22/s while
## sprinting) and frees it ~0.22s later — a pooled VfxSpawner replaces this
## loop in a later pass. Not changed here: this refactor is a pure move
## (Faza 0 point 2), not the spawner work (also Faza 0 point 2 per the
## roadmap, but scoped separately to keep this diff reviewable).
func _spawn_ghost() -> void:
	var frame_texture := _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
	if frame_texture == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = frame_texture
	ghost.global_transform = _sprite.global_transform
	ghost.modulate = GHOST_TINT
	ghost.z_index = _sprite.z_index - 1
	_ghost_parent.add_child(ghost)

	var tween := ghost.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ghost, "modulate:a", 0.0, GHOST_FADE_DURATION)
	tween.tween_property(ghost, "scale", ghost.scale * GHOST_SHRINK_TO, GHOST_FADE_DURATION)
	tween.chain().tween_callback(ghost.queue_free)
