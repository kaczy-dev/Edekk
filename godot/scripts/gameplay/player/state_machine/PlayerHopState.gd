class_name PlayerHopState
extends PlayerState
## Cat mid-hop (PlayerHop's internal timer active — see PlayerHop.is_active()).
## Named "Hop", not the spec's "Jump", deliberately: this is a top-down game,
## Hop is a ground-plane dash with a purely visual arc offset
## (PlayerHop.arc_progress() only moves the sprite's y-offset, not the
## CharacterBody2D itself) — there's no vertical/gravity axis for a
## "PlayerJump"/"PlayerFall" pair to mean anything on. See
## PlayerStateMachine.gd.
