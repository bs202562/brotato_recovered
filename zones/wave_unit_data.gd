@tool
class_name WaveUnitData
extends Resource

enum Type{PLAYER, ENEMY, NEUTRAL, STRUCTURE, BOSS, PET}

@export var type: Type = Type.ENEMY
@export var unit_scene: PackedScene = null
@export var unit_scene_name := "": get = _get_unit_scene_name
@export var min_number: int = 1
@export var max_number: int = 1
@export var spawn_chance: float = 1.0
@export var additional_min_distance_from_player: float = 0.0

func _get_unit_scene_name():
	if unit_scene:
		return unit_scene.resource_path.get_file()
	return ""
