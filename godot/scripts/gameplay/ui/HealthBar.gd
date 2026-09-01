class_name HealthBar
extends Control
## Combat HUD element — rpg.md section 4, feature/rpg-hud. Listens ONLY to
## EventBus (`player_damaged`/`enemy_damaged`/`enemy_died`), never reaches
## into Player/EnemyActor with get_node() — rpg.md's rule 6 ("UI odseparowane
## od logiki, sygnały nie get_node()"), the same separation HUD.gd already
## uses for quests/inventory.
##
## One scene, two roles depending on `enemy_id`:
## - empty string (the default): tracks the player, via EventBus.player_damaged.
## - non-empty: tracks one specific enemy by its node name (the same `name`
##   PlayerHitbox/EnemyHitbox already use as `obj_id` when relaying through
##   EnemyActor — see EnemyActor.gd's EventBus relay), hides itself when
##   that enemy's `enemy_died` fires.
##
## Both player and enemy HealthComponents announce their starting HP via
## EventBus immediately at spawn (PlayerMovement.gd / EnemyActor.gd's relay
## setup) — this bar never needs to guess or default to "full" on its own,
## it just always has a real value by the time it's visible.
##
## rpg.md section "manual playtest" (2026-08-31): the original TextureProgressBar
## + nine_patch_stretch implementation was confirmed BROKEN by an actual
## screenshot (captured via PowerShell window-capture, since no in-engine
## screenshot tool exists here) — the Kenney bar texture rendered its
## background nearly invisible and its fill at the wrong width entirely,
## not a cosmetic nitpick. Rebuilt as two plain ColorRects (Background +
## Fill, Fill's `anchor_right` set to the health ratio) — the standard,
## texture-independent way to build a proportional bar, immune to whatever
## nine-patch quirk caused the texture version to misrender.

@export var enemy_id: String = ""

const FLASH_DURATION := 0.12
const SHAKE_OFFSET := 3.0

var value: float = 0.0:
	set(v):
		value = v
		_update_fill()
var max_value: float = 1.0:
	set(v):
		max_value = maxf(v, 0.01)
		_update_fill()

@onready var _fill: ColorRect = $Fill
var _flash_tween: Tween

func _ready() -> void:
	_update_fill()
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.enemy_damaged.connect(_on_enemy_damaged)
	EventBus.enemy_died.connect(_on_enemy_died)

func _update_fill() -> void:
	if _fill == null:
		return
	_fill.anchor_right = clampf(value / max_value, 0.0, 1.0)

func _on_player_damaged(current_hp: int, max_hp: int) -> void:
	if enemy_id == "":
		var took_damage := current_hp < value
		max_value = max_hp
		value = current_hp
		if took_damage:
			_play_damage_flash()

func _on_enemy_damaged(obj_id: String, current_hp: int, max_hp: int) -> void:
	if enemy_id != "" and obj_id == enemy_id:
		var took_damage := current_hp < value
		max_value = max_hp
		value = current_hp
		if took_damage:
			_play_damage_flash()

## White flash + a tiny horizontal shake — reuses `self` (the bar node) for
## both, no extra Control needed. `_flash_tween` is stopped/restarted rather
## than left to stack, so rapid hits don't queue up an ever-longer shake.
func _play_damage_flash() -> void:
	if _flash_tween and _flash_tween.is_running():
		_flash_tween.kill()
	var base_x := position.x
	position.x = base_x
	modulate = Color.WHITE
	_flash_tween = create_tween()
	_flash_tween.set_trans(Tween.TRANS_SINE)
	_flash_tween.tween_property(self, "modulate", Color(1.6, 0.6, 0.6), FLASH_DURATION * 0.4)
	_flash_tween.parallel().tween_property(self, "position:x", base_x - SHAKE_OFFSET, FLASH_DURATION * 0.25)
	_flash_tween.tween_property(self, "position:x", base_x + SHAKE_OFFSET, FLASH_DURATION * 0.25)
	_flash_tween.parallel().tween_property(self, "modulate", Color.WHITE, FLASH_DURATION * 0.6)
	_flash_tween.tween_property(self, "position:x", base_x, FLASH_DURATION * 0.25)

func _on_enemy_died(obj_id: String) -> void:
	if enemy_id != "" and obj_id == enemy_id:
		hide()
