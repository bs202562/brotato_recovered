tool
class_name WaveUnitData
extends Resource

enum Type{PLAYER, ENEMY, NEUTRAL, STRUCTURE, BOSS, PET}

export (Type) var type = Type.ENEMY
export (PackedScene) var unit_scene: PackedScene = null
export (String) var unit_scene_name: = "" setget , _get_unit_scene_name
export (int) var min_number = 1
export (int) var max_number = 1
export (float) var spawn_chance = 1.0
export (float) var additional_min_distance_from_player = 0.0

func _get_unit_scene_name():
	if unit_scene:
		return unit_scene.resource_path.get_file()
	return ""
