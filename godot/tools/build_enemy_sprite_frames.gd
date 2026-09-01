extends SceneTree
## One-off/rerunnable tool building SpriteFrames .tres for the Tiny RPG
## "Demon_A"/"Blood Monster_A" enemy sprites (rpg.md section 2, feature/
## rpg-enemy) — same "verify, don't guess" discipline as build_theme.gd:
## frame count per animation was confirmed both by dividing each source
## PNG's width by the verified 100px frame size (exact, no remainder) AND by
## visually inspecting Demon_A_Idle/Attack01/Walk.png before writing this.
##
## Source layout: godot/assets/assety/"Tiny RPG Character Asset Pack 02
## -Free Demon_A&Blood Monster_A"/Characters(100x100 split)/<Name>/<Name>/
## <Name>_<Anim>.png — one horizontal strip per animation, 100x100 per
## frame, no "with shadows" variant used (plain version keeps parity with
## everything else in the game, which has no drop-shadow layer today).
##
## Run: godot --headless -s res://tools/build_enemy_sprite_frames.gd
## Output: res://assets/sprite_frames/<name_snake>.tres

const FRAME_SIZE := 100
const SOURCE_ROOT := "res://assets/assety/Tiny RPG Character Asset Pack 02 -Free Demon_A&Blood Monster_A/Characters(100x100 split)"
const OUTPUT_DIR := "res://assets/sprite_frames"

## anim name -> [source file suffix, fps, loop]. Frame COUNT is deliberately
## not hardcoded here — Demon_A and Blood Monster_A turned out to have
## different frame counts per animation despite sharing this pack (verified
## the hard way: a first version of this script hardcoded 8/7 from one
## enemy's dimensions and failed loading the other's Attack01 at 700x100
## instead of the assumed 800x100) — computed per-file from
## texture.get_width() / FRAME_SIZE instead, with a divisibility assert so a
## genuinely malformed sheet still fails loudly rather than silently
## misslicing.
const ANIMATIONS := {
	"idle": ["Idle", 6.0, true],
	"walk": ["Walk", 10.0, true],
	"attack1": ["Attack01", 12.0, false],
	"attack2": ["Attack02", 12.0, false],
	"hurt": ["Hurt", 10.0, false],
	"death": ["Death", 8.0, false],
}

## enemy folder name -> output file snake_case
const ENEMIES := {
	"Demon_A": "demon_a",
	"Blood Monster_A": "blood_monster_a",
}

func _init() -> void:
	## Gotcha found running this: DirAccess.make_dir_recursive_absolute() on a
	## brand-new top-level res:// folder that no editor scan has ever seen
	## silently mis-saves ResourceSaver output into an unrelated existing
	## folder (assets/assety/ here) instead of the freshly-made one, with NO
	## error returned from either call. Fix: pre-create OUTPUT_DIR with a
	## real OS mkdir once (see this branch's session — reproduced and
	## confirmed by re-running after `mkdir` fixed the path), so this call
	## below is a no-op ERR_ALREADY_EXISTS on a real, pre-existing directory.
	var dir_err := DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	if dir_err != OK and dir_err != ERR_ALREADY_EXISTS:
		push_error("build_enemy_sprite_frames: could not create %s (%d)" % [OUTPUT_DIR, dir_err])
		quit(1)
		return

	for folder_name in ENEMIES:
		var out_name: String = ENEMIES[folder_name]
		var frames := _build_for_enemy(folder_name)
		if frames == null:
			quit(1)
			return
		var out_path := "%s/%s.tres" % [OUTPUT_DIR, out_name]
		var save_err := ResourceSaver.save(frames, out_path)
		if save_err != OK:
			push_error("build_enemy_sprite_frames: ResourceSaver.save failed for %s (%d)" % [out_path, save_err])
			quit(1)
			return
		print("build_enemy_sprite_frames: saved %s OK" % out_path)

	quit(0)

func _build_for_enemy(folder_name: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	for anim_name in ANIMATIONS:
		var config: Array = ANIMATIONS[anim_name]
		var suffix: String = config[0]
		var fps: float = config[1]
		var loop: bool = config[2]

		var path := "%s/%s/%s/%s_%s.png" % [SOURCE_ROOT, folder_name, folder_name, folder_name, suffix]
		var texture := load(path) as Texture2D
		if texture == null:
			push_error("build_enemy_sprite_frames: could not load %s" % path)
			return null
		if texture.get_height() != FRAME_SIZE or texture.get_width() % FRAME_SIZE != 0:
			push_error("build_enemy_sprite_frames: %s is %dx%d, not an even multiple of %dpx square frames" % [
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
