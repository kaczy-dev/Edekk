class_name MapPointData
extends Resource
## rpg.md section 27 ("mapa miasta", Szczecin) — one .tres per real-world
## POI lives in godot/data/map_points/. Same shape as ItemData.gd/EnemyData
## (flat Resource, id/name/description/icon), `icon` is an emoji string —
## this game's established "emoji-as-sprite" house style, not a Texture2D;
## no real-world photos of Szczecin are used (licensing, and no fetch tool
## to source them).

@export var id: String
@export var point_name: String
@export var category: String # "waterfront" | "history"
@export var map_position: Vector2
@export var description: String
@export var icon: String
