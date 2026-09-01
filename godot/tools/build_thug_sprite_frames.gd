extends SceneTree
## Builds SpriteFrames for a "thug" enemy (rpg.md art-direction pivot,
## 2026-08-31: modern/contemporary setting, human antagonists instead of
## fantasy monsters) from Tiny Swords' "Warrior" unit (Red Units — a
## visually distinct, antagonist-coded color from the player's own palette).
##
## Frame size verified as 192x192 (texture.get_width() / 192 gives an exact
## frame count for every source file below — same divisibility-assert
## discipline as build_enemy_sprite_frames.gd).
##
## Gap found and documented, not silently worked around: Tiny Swords' Units
## have NO "Hurt" or "Death" animation in ANY color variant (checked all
## five: Black/Blue/Purple/Red/Yellow, all five have exactly Idle/Run/
## Attack1/Attack2/Guard and nothing else). Mitigation:
## - "hurt" is mapped from "Guard" (a defensive flinch reads close enough to
##   a hit-reaction for this foundation pass) rather than inventing frames.
## - "death" is deliberately NOT added — EnemyDeathState.gd falls back to a
##   tween fade-out when sprite_frames.has_animation("death") is false,
##   instead of this tool fabricating a fake death clip from Idle frames.
##
## Run: godot --headless -s res://tools/build_thug_sprite_frames.gd
## Output: res://assets/sprite_frames/thug.tres

const FRAME_SIZE := 192
const OUTPUT_DIR := "res://assets/sprite_frames"

## anim name -> [source file suffix, fps, loop]
const ANIMATIONS := {
	"idle": ["Idle", 6.0, true],
	"walk": ["Run", 10.0, true],
	"attack1": ["Attack1", 12.0, false],
	"attack2": ["Attack2", 12.0, false],
	"hurt": ["Guard", 10.0, false],
}

## output name -> Tiny Swords color folder. "thug" (Red) was the first
## enemy (feature/rpg-combat); "bandit" (Purple) is the second, same
## pipeline, added for rpg.md section 6 point 2 ("drugi wróg") — a visually
## distinct recolor is enough to read as a different enemy type without new
## art, same reasoning as Blood Monster_A being a recolor of Demon_A.
const VARIANTS := {
	"thug": "Red Units",
	"bandit": "Purple Units",
}

func _init() -> void:
	var dir_err := DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	if dir_err != OK and dir_err != ERR_ALREADY_EXISTS:
		push_error("build_thug_sprite_frames: could not create %s (%d)" % [OUTPUT_DIR, dir_err])
		quit(1)
		return

	for out_name in VARIANTS:
		var color_folder: String = VARIANTS[out_name]
		var frames := _build_variant(color_folder)
		if frames == null:
			quit(1)
			return
		var out_path := "%s/%s.tres" % [OUTPUT_DIR, out_name]
		var save_err := ResourceSaver.save(frames, out_path)
		if save_err != OK:
			push_error("build_thug_sprite_frames: ResourceSaver.save failed for %s (%d)" % [out_path, save_err])
			quit(1)
			return
		print("build_thug_sprite_frames: saved %s OK (no 'death' animation — see header)" % out_path)

	quit(0)

func _build_variant(color_folder: String) -> SpriteFrames:
	var source_root := "res://assets/assety/Tiny Swords (Free Pack)/Units/%s/Warrior" % color_folder
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	for anim_name in ANIMATIONS:
		var config: Array = ANIMATIONS[anim_name]
		var suffix: String = config[0]
		var fps: float = config[1]
		var loop: bool = config[2]

		var path := "%s/Warrior_%s.png" % [source_root, suffix]
		var texture := load(path) as Texture2D
		if texture == null:
			push_error("build_thug_sprite_frames: could not load %s" % path)
			return null
		if texture.get_height() != FRAME_SIZE or texture.get_width() % FRAME_SIZE != 0:
			push_error("build_thug_sprite_frames: %s is %dx%d, not an even multiple of %dpx square frames" % [
				path, texture.get_width(), texture.get_height(), FRAME_SIZE
			])
			return null
		var frame_count: int = texture.get_width() / FRAME_SIZE

		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, fps)
		frames.set_animation_loop(anim_name, loop)
		for i in range(frame_count):
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(i * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)
			frames.add_frame(anim_name, atlas)

	return frames
