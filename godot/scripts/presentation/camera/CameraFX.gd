class_name CameraFX
extends Camera2D
## Ported from LevelScene.ts camera pulseZoom/shake (see
## docs/migration/GAMEPLAY_BEHAVIOR.md, section "Kamera"). Attached directly
## to the Player's Camera2D node rather than a separate component, since
## both effects act on this node's own zoom/offset.
##
## Phaser's shake "intensity" is a fraction of screen size and doesn't
## translate 1:1 to Godot's offset-in-pixels model — amplitudes below are
## chosen to feel similar, not literal ports of the 0.001/0.0015 constants.
## Documented divergence, not a missed migration.
##
## NOT yet wired: `reducedMotion` skipping shake — the Settings system isn't
## migrated yet (MIGRATION_MATRIX.md), so shake always plays for now.

var base_zoom := Vector2.ONE

var _shake_remaining := 0.0
var _shake_duration := 0.0
var _shake_amplitude_px := 0.0

var _pulse_remaining := 0.0
var _pulse_duration := 0.0
var _pulse_factor := 1.0

func _process(delta: float) -> void:
	if _shake_remaining > 0.0:
		_shake_remaining -= delta
		var t := _shake_remaining / _shake_duration if _shake_duration > 0.0 else 0.0
		var amount := _shake_amplitude_px * t
		offset = Vector2(randf_range(-amount, amount), randf_range(-amount, amount))
		if _shake_remaining <= 0.0:
			offset = Vector2.ZERO

	if _pulse_remaining > 0.0:
		_pulse_remaining -= delta
		var t2 := clampf(_pulse_remaining / _pulse_duration, 0.0, 1.0) if _pulse_duration > 0.0 else 0.0
		# Ease out: starts at _pulse_factor, settles back to base_zoom.
		zoom = base_zoom.lerp(base_zoom * _pulse_factor, t2)
		if _pulse_remaining <= 0.0:
			zoom = base_zoom

## Ported from LevelScene.ts: `Phaser.Math.Clamp(Math.min(width, height) / 620, 0.75, 1.3)`.
## Called once by LevelRuntime after the viewport size is known — Godot has
## no per-scene "game canvas size" the way Phaser's `this.scale` does, so the
## viewport rect is the equivalent input. Missing this entirely (zoom stuck
## at 1.0) plus missing camera bounds was the "tło za duże / przycina się"
## bug: without either, the camera could scroll past the background
## sprite's edge and reveal the engine's empty clear color, or frame the
## level differently than Phaser did.
func set_base_zoom(z: float) -> void:
	base_zoom = Vector2(z, z)
	zoom = base_zoom

## duration in seconds, amplitude_px in pixels (peak offset).
func shake(duration: float, amplitude_px: float) -> void:
	_shake_duration = duration
	_shake_remaining = duration
	_shake_amplitude_px = amplitude_px

## factor > 1.0 zooms in briefly then eases back to base_zoom over duration seconds.
func pulse_zoom(factor: float, duration: float) -> void:
	_pulse_factor = factor
	_pulse_duration = duration
	_pulse_remaining = duration
