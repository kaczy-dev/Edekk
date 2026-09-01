class_name EnemyAttackState
extends EnemyState
## Player within data.attack_range — stop, telegraph, hit on a repeating
## cycle for as long as the player stays in range. Windup/cooldown are both
## carved out of data.stats.attack_cooldown (40% windup, rest is recovery)
## rather than adding separate StatsData fields — one knob per enemy archetype
## is enough for this foundation pass; split it into two fields later if an
## enemy actually needs an independently-tunable windup.

const WINDUP_FRACTION := 0.4

var _cycle_elapsed := 0.0
var _hit_applied := false

func enter() -> void:
	var sprite: AnimatedSprite2D = enemy.get_node("Sprite2D")
	sprite.play(&"attack1")
	_cycle_elapsed = 0.0
	_hit_applied = false

func physics_update(delta: float, _player: Node2D) -> void:
	enemy.velocity = Vector2.ZERO
	enemy.move_and_slide()

	_cycle_elapsed += delta
	var windup := data.stats.attack_cooldown * WINDUP_FRACTION
	if not _hit_applied and _cycle_elapsed >= windup:
		_hit_applied = true
		var hitbox: EnemyHitbox = enemy.get_node("Hitbox")
		hitbox.apply_hit()

	if _cycle_elapsed >= data.stats.attack_cooldown:
		# Player is still in range (classify() wouldn't be calling this
		# state's physics_update otherwise) — replay the swing rather than
		# exiting, matching a real "keeps attacking while you stand there"
		# enemy instead of one that idles between swings.
		var sprite: AnimatedSprite2D = enemy.get_node("Sprite2D")
		sprite.play(&"attack1")
		_cycle_elapsed = 0.0
		_hit_applied = false
