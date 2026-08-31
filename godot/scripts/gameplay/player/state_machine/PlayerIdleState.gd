class_name PlayerIdleState
extends PlayerState
## Cat stopped (velocity below the anim-move threshold, not mid-hop). No
## body yet — PlayerMovement.gd's own _update_animation() already freezes
## the sprite on its current frame while stationary; this state exists for
## structure (a future pass could move that logic here) not because it does
## something today. See PlayerStateMachine.gd.
