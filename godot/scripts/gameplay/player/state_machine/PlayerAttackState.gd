class_name PlayerAttackState
extends PlayerState
## Cat mid-attack (PlayerAttack.is_active()). Holds the player still —
## EdekSpriteFrames.tres has no attack animation (only walk-up/down/left/
## right; the cat sprite was never authored for combat, rpg.md section 1
## decision #1 deliberately keeps the cat as the player rather than
## swapping to an animated-attack human sprite). The visual "tell" for an
## attack is PlayerVisuals.on_attack_started()'s squash-tween pounce, not a
## sprite animation swap — same reasoning as PlayerHopState reusing the
## walk cycle's current frame rather than a dedicated hop animation.

func physics_update(_delta: float) -> void:
	player.velocity = Vector2.ZERO
