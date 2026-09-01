class_name EnemyIdleState
extends EnemyState
## Player not detected (or not spawned yet) — stand still, play idle.

func enter() -> void:
	var sprite: AnimatedSprite2D = enemy.get_node("Sprite2D")
	sprite.play(&"idle")

func physics_update(_delta: float, _player: Node2D) -> void:
	enemy.velocity = Vector2.ZERO
	enemy.move_and_slide()
