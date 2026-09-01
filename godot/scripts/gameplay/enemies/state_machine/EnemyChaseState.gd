class_name EnemyChaseState
extends EnemyState
## Player within data.detect_radius but outside data.attack_range — walk
## straight toward the player at data.stats.move_speed. No pathfinding
## (NavigationAgent2D) yet — that's docs/ROADMAP.md point 20, out of scope
## for this combat-foundation pass; a straight-line chase is the correct
## "simplest thing that works" for a first enemy on open, mostly-flat
## levels, same way PlayerMovement's own accel/friction started simple
## before drift/lean were added.

func enter() -> void:
	var sprite: AnimatedSprite2D = enemy.get_node("Sprite2D")
	sprite.play(&"walk")

func physics_update(_delta: float, player: Node2D) -> void:
	if player == null:
		enemy.velocity = Vector2.ZERO
		enemy.move_and_slide()
		return
	var direction := (player.global_position - enemy.global_position).normalized()
	enemy.velocity = direction * data.stats.move_speed
	var sprite: AnimatedSprite2D = enemy.get_node("Sprite2D")
	if not is_zero_approx(direction.x):
		sprite.flip_h = direction.x < 0.0
	enemy.move_and_slide()
