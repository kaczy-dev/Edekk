class_name PostFXOverlay
extends CanvasLayer
## Vignette + sepia + hue-rotate — see shaders/post_fx_grade.gdshader for
## why these three specifically (no Environment.adjustment_* equivalent in
## Godot 4's 2D pipeline, unlike brightness/contrast/saturation which
## AtmosphereFX.gd already wires through WorldEnvironment).
##
## `layer = 5`: explicitly between the game world (CanvasLayer default 0)
## and HUD (explicitly `layer = 10` in HUD.tscn, see its own comment) — a
## full-screen SCREEN_TEXTURE read has to sit below the HUD or it would
## vignette/sepia-tint the UI text too, which the Phaser source never did
## (its filters were camera-level, HUD lived outside the Phaser canvas
## entirely in an HTML overlay).

const GradeShader := preload("res://shaders/post_fx_grade.gdshader")

var _rect: ColorRect
var _material: ShaderMaterial

func _ready() -> void:
	layer = 5
	_material = ShaderMaterial.new()
	_material.shader = GradeShader
	_rect = ColorRect.new()
	_rect.material = _material
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.anchor_right = 1.0
	_rect.anchor_bottom = 1.0
	_rect.color = Color(0, 0, 0, 0) # the shader replaces COLOR entirely; this is just so the rect isn't invisible-and-culled
	add_child(_rect)

## `vignette_strength` — Phaser default 0.35 (LevelScene.ts's
## `mood?.vignetteStrength ?? 0.35`), applied unconditionally on every
## level. `apply_sepia`/`hue_degrees` — per-level `mood.sepia`/`mood.hue`,
## 1:1 with AtmosphereFX._setup_post_fx()'s existing brightness/contrast/
## saturation branch (same `mood` dict, same "hand-authored mood overrides
## the generic day/night grade" precedence).
func configure(vignette_strength: float, apply_sepia: bool, hue_degrees: float) -> void:
	_material.set_shader_parameter("vignette_strength", vignette_strength)
	_material.set_shader_parameter("apply_sepia", apply_sepia)
	_material.set_shader_parameter("hue_degrees", hue_degrees)
