class_name EnemyHurtState
extends EnemyState
## Brief stun after taking damage — forced by EnemyStateMachine.force_hurt()
## (called from EnemyActor on HealthComponent.health_changed), not reached
## through the normal distance-based _classify(). EnemyStateMachine owns the
## timer that returns to Idle/Chase/Attack after HURT_DURATION — this state
## itself only plays the animation and holds still.

func enter() -> void:
	var sprite: AnimatedSprite2D = enemy.get_node("Sprite2D")
	sprite.play(&"hurt")

func physics_update(_delta: float, _player: Node2D) -> void:
	enemy.velocity = Vector2.ZERO
	enemy.move_and_slide()
