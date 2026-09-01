class_name TransitDestination
extends Resource
## rpg.md section 6 backlog ("Metro i szybka podróż") — one reachable stop
## from a given TransitStation. Same Resource-as-data pattern as ItemData/
## EnemyData: destinations are authored per-station as .tres sub-resources,
## not hardcoded branches in TransitStation.gd.

@export var display_name: String
@export var target_scene_path: String
@export var cost: int = 4
@export var travel_minutes: int = 30
