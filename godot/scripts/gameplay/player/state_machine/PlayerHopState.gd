class_name PlayerHopState
extends PlayerState
## Cat mid-hop (PlayerHop's internal timer active — see PlayerHop.is_active()).
## Named "Hop", not the spec's "Jump", deliberately: this is a top-down game,
## Hop is a ground-plane dash with a purely visual arc offset
## (PlayerHop.arc_progress() only moves the sprite's y-offset, not the
## CharacterBody2D itself) — there's no vertical/gravity axis for a
## "PlayerJump"/"PlayerFall" pair to mean anything on. See
## PlayerStateMachine.gd.
##
## UPDATE (branch migration/player-physics): this state now owns the actual
## velocity write for Hop — the one piece of "FSM drives physics" scoped for
## this follow-up (plan31-08.md "principal lead" #4). PlayerHop.gd itself is
## UNCHANGED: it still owns detection (buffer/coyote/cooldown, ticked every
## frame regardless of state via PlayerMovement calling _hop.update() every
## frame) and the arc/velocity math — this state is a thin pass-through of
## that frame's already-computed result, not a duplicate implementation of
## hop physics. Moving PlayerHop's OWN internal math into this file too
## would duplicate DURATION/SPEED/arc logic that PlayerMovement's sprite
## y-offset line (`_sprite.position.y = -_hop.arc_progress() * ...`) also
## depends on reading directly — not worth the churn for this pass.

## Set by PlayerStateMachine.physics_update() each frame, right before
## dispatching to this state — this frame's PlayerHop.update() return value
## (guaranteed non-null while this state is active; see _classify()).
var hop_velocity: Vector2 = Vector2.ZERO

func physics_update(_delta: float) -> void:
	player.velocity = hop_velocity
