class_name ToastManager
extends VBoxContainer
## rpg.md section 6 backlog ("piękne, intuicyjne UI z animacjami") — generic
## animated notification stack, first real consumer of EventBus.toast_requested.
## Also the first concrete step toward docs/ROADMAP.md section 28's planned
## "Toasty zamiast jednego MessageLabel" — built generic on purpose so that
## later work reuses this instead of writing a second toast mechanism.
##
## Each toast styles itself through edek_theme.tres (PanelContainer's
## default StyleBoxFlat, Label's "Body" type variation) rather than ad-hoc
## overrides — same discipline CLAUDE.md's Faza 0 Theme work already
## established ("żadnych add_theme_*_override w kodzie gameplayowym").

const ANIM_DURATION := 0.32
const DISPLAY_DURATION := 2.2
const SLIDE_DISTANCE := 28.0
const POP_SCALE_FROM := 0.85

func _ready() -> void:
	EventBus.toast_requested.connect(_show_toast)

func _show_toast(text: String) -> void:
	var panel := PanelContainer.new()
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"Body"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	add_child(panel)

	# Entry state: faded, dropped slightly above, and scaled down for a
	# springy "pop" arrival rather than a flat slide — pivot centered so the
	# scale tween doesn't visibly drift the panel sideways. size is still
	# zero until the VBoxContainer lays this child out, so defer the pivot
	# read to the next frame (after that first layout pass).
	panel.resized.connect(func() -> void: panel.pivot_offset = panel.size / 2.0, CONNECT_ONE_SHOT)
	panel.modulate.a = 0.0
	panel.position.y = -SLIDE_DISTANCE
	panel.scale = Vector2(POP_SCALE_FROM, POP_SCALE_FROM)

	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, ANIM_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(panel, "position:y", 0.0, ANIM_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(panel, "scale", Vector2.ONE, ANIM_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(DISPLAY_DURATION)
	# Exit: fade + scale down together reads as "dismiss", distinct from the
	# pop-in, without adding a second slide direction to track.
	tween.tween_property(panel, "modulate:a", 0.0, ANIM_DURATION * 0.7) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(panel, "scale", Vector2(POP_SCALE_FROM, POP_SCALE_FROM), ANIM_DURATION * 0.7) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(panel.queue_free)
