class_name PlayerHitbox
extends Area2D
## Attack hitbox — rpg.md section 3.1 (layer 7 PlayerHitbox, mask layer 6
## Enemies). Deliberately simpler than a true "monitoring only during the
## active frames" Area2D: `monitoring` stays on permanently (cheap — it only
## ever sees bodies on the Enemies layer), and PlayerMovement calls
## apply_hits() exactly once, at PlayerAttack's attack_hit_window_started
## signal. The functional effect — damage only lands during the attack's hit
## window, never outside it — is the same as toggling monitoring on/off,
## without the Area2D body_entered/exited timing edge cases that toggling
## introduces (a body already overlapping when monitoring flips back on does
## NOT fire body_entered — verified against Godot's Area2D docs before
## picking this approach).
##
## No facing-direction awareness yet — the circle is centered on the player,
## not offset "in front" of them. Player.tscn has no tracked facing vector
## exposed outside PlayerVisuals.last_facing_angle; wiring that in is a
## follow-up polish pass, not required for the combat loop to function.

@export var attack_damage: int = 3

## Enemies already hit by the current swing — cleared on attack_started so
## one swing can't double-hit the same enemy across two calls to
## apply_hits() (not possible with the current single-call design, but kept
## as a guard against a future multi-window swing).
var _hit_this_swing: Array[Node] = []


func reset_swing() -> void:
	_hit_this_swing.clear()


func apply_hits() -> void:
	for body in get_overlapping_bodies():
		if body in _hit_this_swing:
			continue
		if not body.is_in_group("enemy"):
			continue
		var health := body.get_node_or_null("HealthComponent") as HealthComponent
		if health == null or health.is_dead():
			continue
		_hit_this_swing.append(body)
		var status := get_node_or_null("../StatusEffects") as StatusEffectComponent
		var multiplier := status.attack_damage_multiplier if status != null else 1.0
		health.take_damage(roundi(attack_damage * multiplier))
		AudioService.play_hit()
		EventBus.hit_landed.emit(body.global_position)
		# EventBus.enemy_damaged/enemy_died are emitted by EnemyActor's own
		# HealthComponent.health_changed/died relay (see EnemyActor.gd), not
		# here — a single source of truth per entity means the HUD's health
		# bar also sees the enemy's starting HP announced at spawn, not just
		# damage deltas from this one call site (feature/rpg-hud, rpg.md).
