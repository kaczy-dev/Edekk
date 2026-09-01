extends Node
## Ported 1:1 from src/lib/audio.ts (SimpleAudio) — procedural sine-wave SFX
## via WebAudio oscillator + exponential-decay gain envelope. Confirmed by
## reading the source file (not assumed) that no sample assets exist to
## port at all — this resolves the audio decision MIGRATION_MATRIX.md left
## open ("proceduralne vs próbki") in favor of procedural, via Godot's
## AudioStreamGenerator (the direct equivalent of WebAudio oscillator+gain
## synthesis).
##
## Autoload singleton (2nd one, after ProgressStore) — SFX are fired from
## many places across gameplay code, same "genuinely global" bar.
##
## NOT ported: volume/mute settings (Settings system not migrated —
## MIGRATION_MATRIX.md, still ANALYZED), so every play_* call here defaults
## to full volume until that exists. `playDanger` is ported but unused —
## no danger trigger exists yet in any migrated level (LevelBuilder.gd
## doesn't build "trigger" kind objects).

const MIX_RATE := 44100.0
const VOICE_COUNT := 8

class _Voice:
	var player: AudioStreamPlayer
	var playback: AudioStreamGeneratorPlayback
	var active := false
	var freq := 0.0
	var start_volume := 0.0
	var duration_sec := 0.0
	var elapsed := 0.0
	var phase := 0.0

var _voices: Array[_Voice] = []

func _ready() -> void:
	for i in VOICE_COUNT:
		var voice := _Voice.new()
		var player := AudioStreamPlayer.new()
		var stream := AudioStreamGenerator.new()
		stream.mix_rate = MIX_RATE
		stream.buffer_length = 0.3
		player.stream = stream
		add_child(player)
		player.play()
		voice.player = player
		voice.playback = player.get_stream_playback()
		_voices.append(voice)

func _process(_delta: float) -> void:
	for voice in _voices:
		if not voice.active:
			continue
		var playback := voice.playback
		var to_fill := playback.get_frames_available()
		for i in to_fill:
			var t := voice.elapsed / voice.duration_sec
			if t >= 1.0:
				voice.active = false
				break
			# Exponential decay from start_volume down to a near-silent floor —
			# matches gain.exponentialRampToValueAtTime(0.001, ...) in the TS source.
			var amp := voice.start_volume * pow(0.001 / maxf(voice.start_volume, 0.001), t)
			var sample := sin(voice.phase) * amp
			playback.push_frame(Vector2(sample, sample))
			voice.phase += TAU * voice.freq / MIX_RATE
			voice.elapsed += 1.0 / MIX_RATE

func _find_free_voice() -> _Voice:
	for voice in _voices:
		if not voice.active:
			return voice
	return _voices[0]

## duration_ms, volume in [0,1]. Direct port of SimpleAudio.playTone.
func play_tone(freq: float, duration_ms: float, volume: float) -> void:
	if volume <= 0.0:
		return
	var voice := _find_free_voice()
	voice.freq = freq
	voice.start_volume = volume
	voice.duration_sec = duration_ms / 1000.0
	voice.elapsed = 0.0
	voice.phase = 0.0
	voice.active = true

## Ascending chirp: A4 then E5, 60ms apart. Direct port of playPickup.
func play_pickup(volume: float = 1.0) -> void:
	play_tone(440.0, 100.0, volume * 0.4)
	get_tree().create_timer(0.06).timeout.connect(play_tone.bind(659.0, 100.0, volume * 0.4))

## Bell chord (C5/E5/G5 major triad). Direct port of playCompletion.
func play_completion(volume: float = 1.0) -> void:
	play_tone(523.0, 200.0, volume * 0.3)
	play_tone(659.0, 200.0, volume * 0.3)
	play_tone(784.0, 200.0, volume * 0.3)

## Warning buzz: two A3 pulses 100ms apart. Direct port of playDanger.
func play_danger(volume: float = 1.0) -> void:
	play_tone(220.0, 80.0, volume * 0.4)
	get_tree().create_timer(0.1).timeout.connect(play_tone.bind(220.0, 80.0, volume * 0.4))

## Combat SFX — rpg.md's backlog item "Dźwięki combat" (feature/rpg-combat had
## none; added once the loop needed the polish). Same procedural approach as
## everything above — no sample assets exist for this, matching this file's
## own header note ("no sample assets exist to port at all"), and a single
## fixed-frequency `play_tone()` can't do a real pitch sweep, so "swing"/
## "hit" are approximated with the closest single-tone equivalent rather
## than left silent.

## Short high tick for a weapon swing — played on PlayerAttack.attack_started,
## regardless of whether it connects (a swing makes a sound whether or not it
## hits; play_hit() below is the separate "it landed" cue).
func play_swing(volume: float = 1.0) -> void:
	play_tone(900.0, 50.0, volume * 0.25)

## Percussive thud for a landed hit (player's or an enemy's) — low frequency,
## fast decay, deliberately punchier/louder than the swing tick above so a
## connecting attack reads as distinct from a whiffed one.
func play_hit(volume: float = 1.0) -> void:
	play_tone(140.0, 90.0, volume * 0.45)

## Three-note descending cue for an enemy's death — the inverse shape of
## play_completion()'s ascending major triad above, so "defeat" and
## "success" read as opposites using the same synthesis technique.
func play_enemy_defeated(volume: float = 1.0) -> void:
	play_tone(392.0, 120.0, volume * 0.35)
	get_tree().create_timer(0.09).timeout.connect(play_tone.bind(330.0, 120.0, volume * 0.35))
	get_tree().create_timer(0.18).timeout.connect(play_tone.bind(262.0, 180.0, volume * 0.35))
