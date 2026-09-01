extends Node2D
## Pooled hit-impact VFX — rpg.md section 3.6/section 4 point 5
## (feature/rpg-vfx). Autoload (seventh, alongside ProgressStore/
## AudioService/SettingsStore/EventBus/DebugConsole/SceneRouter) so it can
## catch EventBus.hit_landed regardless of which level is active, the same
## reasoning as AudioService being global rather than per-level.
##
## This is the actual fix for the anti-pattern docs/ROADMAP.md's audit
## flagged (section "Audyt zgodności z zasadami 4-7", rule 7): PlayerVisuals
## ._spawn_ghost() allocates a new Sprite2D every ~45ms during a sprint and
## frees it ~0.22s later (~22 allocations/sec in the hottest path in the
## game) — that TODO is still there, unchanged (out of scope for this
## combat-only pass), but new VFX code does NOT repeat it: a fixed pool of
## AnimatedSprite2D nodes, created once in _ready(), cycled round-robin
## rather than allocated/freed per hit.
##
## Effect: Tiny Swords' Explosion_01.png (8 frames, 192x192/frame, verified
## via texture.get_width()/192) — a small bright burst that fades to dust,
## generic enough to read as "something got hit" for both the player's and
## an enemy's impacts without needing separate effects per side yet.

const POOL_SIZE := 8
const FRAME_SIZE := 192
const SOURCE_PATH := "res://assets/assety/Tiny Swords (Free Pack)/Particle FX/Explosion_01.png"
const FPS := 24.0
const DISPLAY_SCALE := 0.35 # 192px source down to a HUD-appropriate hit-spark size

var _pool: Array[AnimatedSprite2D] = []
var _next_index := 0

func _ready() -> void:
	var frames := _build_frames()
	for i in range(POOL_SIZE):
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = frames
		sprite.scale = Vector2(DISPLAY_SCALE, DISPLAY_SCALE)
		sprite.visible = false
		sprite.animation_finished.connect(func() -> void: sprite.visible = false)
		add_child(sprite)
		_pool.append(sprite)
	EventBus.hit_landed.connect(_on_hit_landed)

func _build_frames() -> SpriteFrames:
	var texture := load(SOURCE_PATH) as Texture2D
	@warning_ignore("integer_division") # exact by construction — FRAME_SIZE evenly divides this texture's width
	var frame_count: int = texture.get_width() / FRAME_SIZE
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation(&"hit")
	frames.set_animation_speed(&"hit", FPS)
	frames.set_animation_loop(&"hit", false)
	for i in range(frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(i * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)
		frames.add_frame(&"hit", atlas)
	return frames

## Round-robin, not "find a free slot" — simpler, and with POOL_SIZE (8)
## comfortably above how many hits can realistically land within one
## effect's short lifetime (8 frames @ 24fps = ~0.33s) in this game's actual
## combat pace (one player swing every >=0.25s cooldown, one enemy attack
## per >=1s cycle — see PlayerAttack.COOLDOWN / EnemyAttackState's windup
## fraction of StatsData.attack_cooldown), a slot being mid-animation when
## its turn comes back around again is not expected in practice. If it ever
## happens, that slot's effect just cuts off and restarts — an acceptable
## trade for zero per-hit allocation.
func _on_hit_landed(hit_position: Vector2) -> void:
	var sprite := _pool[_next_index]
	_next_index = (_next_index + 1) % POOL_SIZE
	sprite.global_position = hit_position
	sprite.visible = true
	sprite.play(&"hit")
