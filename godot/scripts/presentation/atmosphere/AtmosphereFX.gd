class_name AtmosphereFX
extends Node2D
## Ported subset of src/game/phaser/AtmosphereFX.ts: point light + cat-
## following light (additive glow sprite, not Godot's Light2D system — same
## reasoning as the Phaser source avoiding its engine's native lighting
## pipeline: simple additive sprites are a stable, renderer-agnostic API,
## while getting genuine 2D dynamic lighting right, with occluders, is a
## much bigger and riskier undertaking to sink into a still-greybox game),
## and ambient drifting particles (`CPUParticles2D`, one per `ambientFx`
## type: motes/dust/petals/stars).
##
## Post-FX colour grade (see _setup_post_fx()) covers brightness/contrast/
## saturation via `WorldEnvironment` + `Environment.adjustment_*` — flagged
## R2 "API niepewne" in the original audit, **confirmed working in-editor by
## the user (2026-08-31)**. Vignette + hue-rotation/sepia now covered too,
## via PostFXOverlay.gd's custom shader — Environment has no equivalent for
## either in Godot 4's 2D pipeline. NOT ported: foreground leaf layer
## (`setupForegroundLeaves`) — same particle approach as ambient particles,
## but needs its own leaf-shaped texture and depth-layering decision,
## skipped to keep this slice reviewable.
##
## Ambient particle velocities are an approximation: the TS source gives
## independent min/max X and Y speed ranges per effect; `CPUParticles2D`
## only exposes direction + spread + a single radial speed range, so exact
## per-axis ranges don't carry over 1:1. Tuned to read similarly, not
## measured against the original.
##
## Część 10 (plan31-08.md) added real `PointLight2D` + shadows (obstacles
## get a matching `LightOccluder2D` in LevelBuilder._build_occluder()) on
## top of — not instead of — the additive glow sprites above. Deliberately
## additive: the glow sprites are the confirmed-working, user-tested look
## for L1 (patrz MIGRATION_MATRIX.md); swapping them out for pure Light2D
## risked changing a look that already shipped. Also deliberately NOT
## added: the spec's `CanvasModulate` global night tint — L1's `mood`
## (brightness/contrast/saturation via post-fx, already tuned and confirmed
## by the user) would very likely clash with a second, independent global
## darkening pass without a way to visually verify the combination in this
## session. Shadows read as a clean addition (dark obstacle silhouettes
## where none existed); a scene-wide color tint does not have that same
## "can only make it more correct, not visually break it" property.

func setup(level: LevelData, player: Node2D) -> void:
	_setup_point_light(level)
	_setup_ambient_particles(level)
	_setup_cat_light(level, player)
	_setup_post_fx(level)
	_setup_foreground_leaves(level)

## Ported subset of AtmosphereFX.ts's setupPostFX(): brightness/contrast/
## saturation only (see file header for what's NOT covered). `level.mood`
## (per-level hand-authored values) takes over entirely when present,
## otherwise falls back to a continuous day/night blend driven by
## `level.ambient`, exactly like the TS source's `night` lerp factor
## (0 = day, 0.5 = dim, 1 = night).
func _setup_post_fx(level: LevelData) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_KEEP
	env.adjustment_enabled = true

	var mood := level.mood
	if not mood.is_empty():
		env.adjustment_brightness = mood.get("brightness", 1.0)
		env.adjustment_contrast = mood.get("contrast", 1.0)
		# TS `saturate` is an additive delta (0 = unchanged); Godot's
		# `adjustment_saturation` is a multiplier (1 = unchanged).
		env.adjustment_saturation = 1.0 + float(mood.get("saturate", 0.0))
	else:
		var night := 1.0 if level.ambient == "night" else (0.5 if level.ambient == "dim" else 0.0)
		env.adjustment_brightness = lerpf(1.02, 0.92, night)
		env.adjustment_contrast = lerpf(1.04, 1.08, night)
		env.adjustment_saturation = 1.0 + lerpf(0.06, -0.1, night)

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	# Vignette + sepia/hue — see PostFXOverlay.gd. Vignette strength mirrors
	# Phaser's unconditional default (LevelScene.ts:
	# `mood?.vignetteStrength ?? 0.35`) since no ported level's `mood`
	# overrides it. Sepia/hue read straight off the same `mood` dict the
	# brightness/contrast/saturation branch above already uses — same
	# "hand-authored mood, not the day/night fallback" data, just the two
	# fields that branch couldn't apply itself.
	var overlay := PostFXOverlay.new()
	add_child(overlay)
	var vignette_strength: float = mood.get("vignetteStrength", 0.35) if not mood.is_empty() else 0.35
	var apply_sepia: bool = mood.get("sepia", false)
	var hue_degrees: float = mood.get("hue", 0.0)
	overlay.configure(vignette_strength, apply_sepia, hue_degrees)

func _make_glow_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex

func _additive_material() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat

## `css` is an `rgba(r,g,b,a)` string (LevelData.point_light["color"], carried
## over verbatim from the TS source's CSS-string format).
func _parse_css_color(css: String) -> Color:
	var regex := RegEx.new()
	regex.compile("rgba?\\(\\s*(\\d+)\\s*,\\s*(\\d+)\\s*,\\s*(\\d+)")
	var m := regex.search(css)
	if m == null:
		return Color.WHITE
	return Color8(m.get_string(1).to_int(), m.get_string(2).to_int(), m.get_string(3).to_int())

func _setup_point_light(level: LevelData) -> void:
	if level.point_light.is_empty():
		return
	var pl := level.point_light
	var color: Color = _parse_css_color(pl.get("color", "rgba(255,255,255,1)"))
	var intensity: float = pl.get("intensity", 0.7)

	var glow := Sprite2D.new()
	glow.texture = _make_glow_texture()
	glow.material = _additive_material()
	glow.modulate = Color(color.r, color.g, color.b, 1.0)
	glow.self_modulate.a = intensity
	glow.scale = Vector2(2.4, 2.4)
	glow.position = Vector2(pl.get("x", 0.0), pl.get("y", 0.0))
	add_child(glow)

	# Gentle flicker so the fixed light doesn't read as a static decal.
	var tween := create_tween().set_loops()
	tween.tween_property(glow, "self_modulate:a", intensity * 0.75, 0.9).from(intensity)
	tween.tween_property(glow, "self_modulate:a", intensity, 0.9)

	add_child(_make_shadow_light(color, intensity, glow.position))

## Real Light2D counterpart to the additive glow sprite above — same
## position/color, but this is the one that actually casts shadows against
## LightOccluder2D (LevelBuilder._build_occluder(), one per obstacle). The
## glow sprite alone never darkened anything behind an obstacle; this is
## purely additive on top of it (see file header, "Część 10").
func _make_shadow_light(color: Color, intensity: float, pos: Vector2) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = _make_glow_texture()
	light.color = color
	light.energy = intensity
	light.position = pos
	light.texture_scale = 3.2
	light.shadow_enabled = true
	return light

func _setup_cat_light(level: LevelData, player: Node2D) -> void:
	if level.ambient != "night" and level.ambient != "dim":
		return
	const CAT_LIGHT_COLOR := Color(1.0, 0.863, 0.659) # 0xffdca8
	var glow := Sprite2D.new()
	glow.texture = _make_glow_texture()
	glow.material = _additive_material()
	glow.modulate = CAT_LIGHT_COLOR
	glow.self_modulate.a = 0.28
	glow.scale = Vector2(1.1, 1.1)
	# Parented to the player so it tracks position for free — no per-frame
	# update() call needed, unlike the Phaser source's updateCatLight().
	player.add_child(glow)
	player.add_child(_make_shadow_light(CAT_LIGHT_COLOR, 0.55, Vector2.ZERO))

const _PARTICLE_CONFIG := {
	"motes": {"color": Color8(255, 220, 168, 64), "direction": Vector2(0, -1), "spread": 30.0, "speed": 5.0, "scale": 0.5},
	"dust": {"color": Color8(216, 203, 168, 46), "direction": Vector2(0, 0), "spread": 180.0, "speed": 5.0, "scale": 0.6},
	"petals": {"color": Color8(255, 182, 193, 128), "direction": Vector2(0, 1), "spread": 25.0, "speed": 20.0, "scale": 0.7},
	"stars": {"color": Color8(255, 255, 255, 178), "direction": Vector2(0, 0), "spread": 180.0, "speed": 2.0, "scale": 0.35},
}

## Ported from AtmosphereFX.ts's setupForegroundLeaves() — called
## unconditionally for every level there too (gated only by Phaser's
## render-quality tier, which this project never ported — see
## MIGRATION_MATRIX.md's "Świadome odejścia"), not by `level.ambientFx`
## like _setup_ambient_particles() above. The TS source itself draws a
## procedural ellipse silhouette (`graphics.fillEllipse(5,3,10,6)`), not a
## real leaf sprite/asset — so this is a 1:1 port, not a placeholder standing
## in for missing art (there was never any leaf art in the source to miss).
##
## Approximations, documented rather than hidden: TS picks a random tint per
## particle from a 4-color palette (`leafTints`); CPUParticles2D has no
## per-particle random-from-list, only a single fixed color or a lifetime
## color_ramp, so this uses one averaged autumn-orange tone instead of four
## discrete ones. TS's `scale: {start:0.9, end:0.7}` (shrink over lifetime)
## is approximated as a fixed random range instead of an animated curve, to
## keep this addition small — the visual difference is minor for a sparse,
## in-front-of-everything ambience layer.
const _LEAF_TINT := Color8(196, 138, 68, 217) # ~average of TS's 4-color leafTints, alpha ~0.85

func _setup_foreground_leaves(level: LevelData) -> void:
	var particles := CPUParticles2D.new()
	particles.texture = _make_leaf_texture()
	particles.amount = 12 # lifetime 9s / ~1 spawn per 0.95s ≈ ~9-10 concurrent, some margin
	particles.lifetime = 9.0
	particles.preprocess = 4.0 # scene reads as already-populated on level start
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(level.width / 2.0, (level.height + 40.0) / 2.0)
	particles.position = Vector2(level.width / 2.0, level.height / 2.0 - 20.0)
	particles.direction = Vector2(0, 1)
	particles.spread = 50.0 # approximates TS's independent speedX(-14..14)/speedY(8..18) cone
	particles.initial_velocity_min = 8.0
	particles.initial_velocity_max = 20.0
	particles.angle_min = 0.0
	particles.angle_max = 360.0
	particles.scale_amount_min = 0.7
	particles.scale_amount_max = 0.9
	particles.color = _LEAF_TINT
	# Above the cat/world/cat-light, same as the TS source's
	# `layerDepths.foreground` — but still below PostFXOverlay's layer=5
	# CanvasLayer (SCREEN_TEXTURE-based vignette/grade), so the leaves get
	# graded/vignetted along with everything else, matching Phaser where the
	# post-FX filters were camera-level and caught the whole scene including
	# this layer.
	particles.z_index = 500
	add_child(particles)

## Small procedural ellipse silhouette — 1:1 with TS's
## `graphics.fillEllipse(5, 3, 10, 6)` (a 10x6 canvas, ellipse centered at
## (5,3) with those radii), generated once per level the same way
## _make_glow_texture() generates its radial gradient.
func _make_leaf_texture() -> ImageTexture:
	var w := 10
	var h := 6
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var cx := 5.0
	var cy := 3.0
	var rx := 5.0
	var ry := 3.0
	for y in h:
		for x in w:
			var nx := (x + 0.5 - cx) / rx
			var ny := (y + 0.5 - cy) / ry
			img.set_pixel(x, y, Color(1, 1, 1, 1) if nx * nx + ny * ny <= 1.0 else Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)

func _setup_ambient_particles(level: LevelData) -> void:
	if level.ambient_fx == "" or not _PARTICLE_CONFIG.has(level.ambient_fx):
		return
	var cfg: Dictionary = _PARTICLE_CONFIG[level.ambient_fx]

	var particles := CPUParticles2D.new()
	particles.amount = 40
	particles.lifetime = 6.0
	particles.preprocess = 4.0 # scene reads as already-populated on level start, not empty-then-filling
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(level.width / 2.0, level.height / 2.0)
	particles.position = Vector2(level.width / 2.0, level.height / 2.0)
	particles.direction = cfg.direction
	particles.spread = cfg.spread
	particles.initial_velocity_min = cfg.speed * 0.4
	particles.initial_velocity_max = cfg.speed
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = cfg.scale * 0.6
	particles.scale_amount_max = cfg.scale
	particles.color = cfg.color
	particles.z_index = 3
	add_child(particles)
