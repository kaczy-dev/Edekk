class_name EnemyHitbox
extends Area2D
## Mirror of PlayerHitbox.gd for the enemy side (rpg.md section 3.1, layer 8
## EnemyHitbox, mask layer 2 Player). Same "monitoring always on, apply_hit()
## called explicitly at the right moment" design — see PlayerHitbox.gd's
## header for why that's equivalent to toggling monitoring without the
## Area2D signal-timing edge cases.
##
## Unlike PlayerHitbox there's no per-swing "already hit" guard: EnemyAttackState
## calls apply_hit() at most once per its own windup/cooldown cycle, so the
## same double-hit concern doesn't apply here.

@export var attack_damage: int = 2

func apply_hit() -> void:
	for body in get_overlapping_bodies():
		if not body.is_in_group("player"):
			continue
		var health := body.get_node_or_null("HealthComponent") as HealthComponent
		if health == null or health.is_dead():
			continue
		health.take_damage(Difficulty.scaled_damage(attack_damage, SettingsStore.difficulty))
		AudioService.play_hit()
		EventBus.hit_landed.emit(body.global_position)
		# EventBus.player_damaged is emitted by PlayerMovement's own
		# HealthComponent.health_changed relay (see PlayerMovement.gd), not
		# here — same single-source-of-truth reasoning as PlayerHitbox.gd.
