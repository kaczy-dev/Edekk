class_name LevelBuilder
extends RefCounted
## Instantiates a LevelData resource's `objects` array into a live scene:
## "obstacle" -> StaticBody2D, "item" -> ItemPickup, "goal" -> GoalArea,
## "npc" -> NpcActor. "trigger" (danger) is not built yet — no currently
## ported level uses it, see docs/migration/MIGRATION_MATRIX.md.
##
## Static-only. Takes the Node2D to parent spawned objects under, so it has
## no scene-tree state of its own.

const ItemPickupScene := preload("res://scenes/interactables/ItemPickup.tscn")
const GoalAreaScene := preload("res://scenes/interactables/GoalArea.tscn")
const NpcActorScene := preload("res://scenes/interactables/NpcActor.tscn")

const DEFAULT_ITEM_ICON := "❓"
const DEFAULT_GOAL_ICON := "❓"
const DEFAULT_NPC_ICON := "❓"

## Returns the spawned item pickups, goal areas and NPCs (Array[Node2D]) so
## the caller can connect their signals — building doesn't wire up gameplay.
## `collected_ids` (from ProgressStore, persisted across level re-entries)
## skips already-collected "item" objects, mirroring LevelScene.ts's
## `obj.collected || collectedIds.has(obj.id)` guard. `hide_obstacle_visual`
## drops the grey Polygon2D placeholder (collision stays) when the level has
## a real background texture already depicting that geometry — see
## LevelRuntime._setup_background()/LevelBackgrounds.gd. `items` is the
## ItemRegistry.load_all() dictionary, used to resolve each item's emoji
## glyph (ported from LevelScene.ts: `obj.icon ?? ITEMS[obj.itemId]?.emoji`
## — items render as emoji text there too, not custom sprites, so this is a
## 1:1 visual port, not a greybox stand-in).
static func build(parent: Node2D, level: LevelData, collected_ids: Array = [], hide_obstacle_visual: bool = false, items: Dictionary = {}) -> Array:
	var interactables := []
	for obj in level.objects:
		match obj.kind:
			"obstacle":
				parent.add_child(_build_obstacle(obj, hide_obstacle_visual))
			"item":
				if collected_ids.has(obj.id):
					continue
				var pickup := _build_item_pickup(obj, items)
				parent.add_child(pickup)
				interactables.append(pickup)
			"goal":
				var goal := _build_goal_area(obj)
				parent.add_child(goal)
				interactables.append(goal)
			"npc":
				var npc := _build_npc(obj)
				parent.add_child(npc)
				interactables.append(npc)
			_:
				push_warning("LevelBuilder: kind '%s' (obj '%s') not implemented yet" % [obj.kind, obj.id])
	return interactables

static func _rect_center(rect: Rect2) -> Vector2:
	return rect.position + rect.size / 2.0

## Centered rectangle points for a Polygon2D placeholder — no art imported
## yet (god/godotassets.md, Faza asset import), this is deliberate greybox.
static func _rect_polygon(size: Vector2) -> PackedVector2Array:
	var hw := size.x / 2.0
	var hh := size.y / 2.0
	return PackedVector2Array([Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)])

static func _build_obstacle(obj: LevelObjectData, hide_visual: bool = false) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = "Obstacle_%s" % obj.id
	body.position = _rect_center(obj.rect)
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = obj.rect.size
	shape.shape = rect_shape
	body.add_child(shape)

	var visual := Polygon2D.new()
	visual.color = Color(0.35, 0.35, 0.4, 1.0)
	visual.polygon = _rect_polygon(obj.rect.size)
	visual.visible = not hide_visual
	body.add_child(visual)

	# Requested after user testing found real-background levels had zero
	# visual cue at obstacle edges (matches Phaser's own `rect.setVisible(false)`
	# — collision there is invisible too, this is a deliberate departure from
	# strict parity, not a bug fix). A subtle outline instead of the solid
	# fill, so it doesn't fight with the real background art underneath.
	var outline := Line2D.new()
	outline.points = _rect_outline(obj.rect.size)
	outline.width = 2.0
	outline.default_color = Color(1.0, 1.0, 1.0, 0.35)
	outline.visible = hide_visual
	body.add_child(outline)

	body.add_child(_build_occluder(obj.rect.size))

	return body

## Część 10 (plan31-08.md): every obstacle casts a shadow from
## AtmosphereFX's PointLight2D nodes (point light on night levels, the
## player's own night-vision glow). Cheap to add unconditionally — a
## LightOccluder2D with no Light2D in the scene (day levels, no `mood`
## night ambient) has no visible effect and costs nothing at render time.
static func _build_occluder(size: Vector2) -> LightOccluder2D:
	var occluder := LightOccluder2D.new()
	var polygon := OccluderPolygon2D.new()
	polygon.polygon = _rect_polygon(size)
	occluder.occluder = polygon
	return occluder

## Closed-loop outline points (first point repeated at the end) for Line2D.
static func _rect_outline(size: Vector2) -> PackedVector2Array:
	var hw := size.x / 2.0
	var hh := size.y / 2.0
	return PackedVector2Array([Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh), Vector2(-hw, -hh)])

static func _build_item_pickup(obj: LevelObjectData, items: Dictionary) -> ItemPickup:
	var pickup := ItemPickupScene.instantiate() as ItemPickup
	pickup.name = "Item_%s" % obj.id
	pickup.position = _rect_center(obj.rect)
	pickup.obj_id = obj.id
	pickup.item_id = obj.item_id
	pickup.set_shape_size(obj.rect.size)
	var item: ItemData = items.get(obj.item_id)
	pickup.set_icon(obj.icon if obj.icon != "" else (item.emoji if item else DEFAULT_ITEM_ICON))
	return pickup

static func _build_goal_area(obj: LevelObjectData) -> GoalArea:
	var goal := GoalAreaScene.instantiate() as GoalArea
	goal.name = "Goal_%s" % obj.id
	goal.position = _rect_center(obj.rect)
	goal.obj_id = obj.id
	goal.requires = obj.requires
	goal.message = obj.message
	goal.set_shape_size(obj.rect.size)
	goal.set_icon(obj.icon if obj.icon != "" else DEFAULT_GOAL_ICON)
	return goal

static func _build_npc(obj: LevelObjectData) -> NpcActor:
	var npc := NpcActorScene.instantiate() as NpcActor
	npc.name = "Npc_%s" % obj.id
	npc.position = _rect_center(obj.rect)
	npc.obj_id = obj.id
	npc.npc_id = obj.npc_id
	npc.patrol_range = obj.patrol_range
	npc.patrol_speed = obj.patrol_speed
	npc.set_shape_size(obj.rect.size)
	npc.set_icon(obj.icon if obj.icon != "" else DEFAULT_NPC_ICON)
	return npc
