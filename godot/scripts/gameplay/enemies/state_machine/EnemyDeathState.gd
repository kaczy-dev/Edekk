class_name EnemyDeathState
extends EnemyState
## Terminal state — forced by EnemyStateMachine.force_death() (HealthComponent
## .died). Disables collision so the corpse stops blocking movement/being
## hit again mid-death-animation, plays the death clip once, then frees the
## whole EnemyActor when it finishes. There is deliberately no path out of
## this state (EnemyStateMachine.physics_update() short-circuits on
## StateName.DEAD before ever calling _classify() again).
##
## Not every enemy has a "death" animation — Tiny Swords' Units (the "thug"
## archetype, rpg.md's contemporary-setting pivot) have none in any color
## variant (checked all five). Falls back to a tween fade-out + queue_free
## instead of forcing a fake death clip out of frames that were never meant
## to represent it (see build_thug_sprite_frames.gd's header).

const FADE_DURATION := 0.4

func enter() -> void:
	AudioService.play_enemy_defeated()
	var body_shape: CollisionShape2D = enemy.get_node("CollisionShape2D")
	body_shape.set_deferred("disabled", true)
	var hitbox: EnemyHitbox = enemy.get_node("Hitbox")
	hitbox.set_deferred("monitoring", false)

	var sprite: AnimatedSprite2D = enemy.get_node("Sprite2D")
	if sprite.sprite_frames.has_animation(&"death"):
		sprite.play(&"death")
		sprite.animation_finished.connect(enemy.queue_free, CONNECT_ONE_SHOT)
	else:
		var tween := enemy.create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, FADE_DURATION)
		tween.tween_callback(enemy.queue_free)

func physics_update(_delta: float, _player: Node2D) -> void:
	enemy.velocity = Vector2.ZERO
