extends GutTest
## rpg.md backlog item "Dźwięki combat" (closed 2026-08-31) — procedural SFX
## added to the real AudioService autoload. Asserts a voice actually
## activates (frequency/duration set) rather than just "no crash" — reading
## `_voices` directly is legal here the same way test_combat.gd/etc. treat
## `_`-prefixed fields as accessible in-repo (convention, not real privacy,
## per this project's own established GDScript style).

func _any_active_voice_with_freq(freq: float) -> bool:
	for voice in AudioService._voices:
		if voice.active and is_equal_approx(voice.freq, freq):
			return true
	return false

func test_play_swing_activates_a_voice() -> void:
	AudioService.play_swing()
	assert_true(_any_active_voice_with_freq(900.0))

func test_play_hit_activates_a_voice() -> void:
	AudioService.play_hit()
	assert_true(_any_active_voice_with_freq(140.0))

func test_play_enemy_defeated_activates_first_note_immediately() -> void:
	AudioService.play_enemy_defeated()
	assert_true(_any_active_voice_with_freq(392.0), "first descending note plays immediately, the other two are timer-delayed")
