extends Node
## Self-driving screenshot harness — QA tool for verifying HUD-level UI
## (compass, toasts, energy/health labels) without needing OS-level input
## injection, which rpg.md section 11d found does NOT reliably reach a real
## Godot window (PowerShell SendKeys tried and failed against the actual
## game window). This scene instead drives HUD state directly through
## GDScript (the same calls LevelRuntime/EventBus would make), waits a few
## frames for tweens/animations to settle, grabs the actual rendered
## viewport texture, and writes it to disk — then quits itself. Run via
## `mcp__godot__run_project` pointed at UIVerify.tscn, then read the PNG.
##
## Not a permanent feature and not exported — lives under scripts/dev/ next
## to the equivalent ad-hoc TestCombat.tscn/TestEconomy.tscn hand scenes,
## reusable QA tooling in the same spirit as DebugConsole's `/advance_day`.

const OUT_PATH := "user://ui_verify.png"

func _ready() -> void:
	var hud: HUD = preload("res://scenes/ui/HUD.tscn").instantiate()
	add_child(hud)
	await get_tree().process_frame

	# One direction per shot, isolated (no toast) so the compass arrow is
	# unambiguous — RIGHT/DOWN/LEFT/UP in turn.
	var dirs := {"right": Vector2.RIGHT, "down": Vector2.DOWN, "left": Vector2.LEFT, "up": Vector2.UP}
	for dir_name in dirs:
		hud.update_proximity({"q": ProximityTrack.new("near", 50.0, dirs[dir_name])})
		await get_tree().process_frame
		hud._process(0.5) # force the lerp/rotation update this frame, not next
		await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("user://ui_verify_compass_%s.png" % dir_name)

	# Toast + energy label, separately, to check overlap with the compass.
	hud.update_proximity({"q": ProximityTrack.new("near", 50.0, Vector2.RIGHT)})
	hud.update_energy(15.0, false)
	EventBus.toast_requested.emit("Podsumowanie dnia: +20 zł, -5 zł, 1 starć")
	await get_tree().create_timer(0.3).timeout
	await get_tree().process_frame
	var img2 := get_viewport().get_texture().get_image()
	img2.save_png(OUT_PATH)

	# rpg.md section 11b ("Sezonowe/dzienne promocje w automatach") — same
	# self-driving-screenshot technique, applied to a gameplay node instead
	# of just HUD this time: force a promo day, force a non-promo day, shoot
	# both so the PromoBadge's visibility is actually seen, not just asserted.
	var machine: VendingMachine = preload("res://scenes/economy/VendingMachine.tscn").instantiate()
	add_child(machine)
	machine.position = Vector2(640, 300)
	await get_tree().process_frame
	var real_day := TimeManager.current_day

	TimeManager.current_day = 2 # Wednesday — promo active
	machine.get_node("PromoBadge").visible = machine._is_promo_active()
	await get_tree().process_frame
	var promo_img := get_viewport().get_texture().get_image()
	promo_img.save_png("user://ui_verify_vending_promo.png")

	TimeManager.current_day = 0 # Monday — no promo
	machine.get_node("PromoBadge").visible = machine._is_promo_active()
	await get_tree().process_frame
	var no_promo_img := get_viewport().get_texture().get_image()
	no_promo_img.save_png("user://ui_verify_vending_no_promo.png")
	TimeManager.current_day = real_day

	# rpg.md section 11b ("Graffiti/ślady gracza") — a handful of scattered
	# combat traces via the real EventBus signal, camera-agnostic (Node2D
	# world space, not HUD), same self-driving-screenshot technique again.
	var trace_positions := [Vector2(300, 200), Vector2(360, 260), Vector2(320, 340), Vector2(500, 220)]
	for pos in trace_positions:
		EventBus.combat_trace_requested.emit(pos)
	await get_tree().process_frame
	var graffiti_img := get_viewport().get_texture().get_image()
	graffiti_img.save_png("user://ui_verify_graffiti.png")

	print("UI_VERIFY_SAVED: %s" % ProjectSettings.globalize_path(OUT_PATH))
	get_tree().quit()
