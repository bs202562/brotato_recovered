extends ItemParentData
class_name ItemEntity

export(Resource) var stats
export(String) var behaviour_description = ""
export(bool) var show_hp : bool = true
export(bool) var show_dammage : bool = true
export(bool) var show_speed : bool = true
export(bool) var show_knoback_resistance : bool = true
export(bool) var show_material_dropped : bool = true
export(Texture) var screen_example : Texture

func _set_item_stat(new_enemy_stats : Stats, id : String) -> void:
	my_id = id
	stats = new_enemy_stats
	icon = stats.icon
	name = stats.name


func _get_entity_description( side : int = 0, hide_if_non_unlock_in_codex : bool = false)-> String:
	if _is_locked_in_codex() and hide_if_non_unlock_in_codex :
		if side <= 0 :
			return Text.text("CODEX_NEED_TO_KILL_MORE")
		else :
			return("")

	var text : String = ""

	text += _write_description_line("CODEX_ENEMY_SPEED", stats.speed, Keys.stat_speed_hash, side)
	return text


func _get_entity_player_stats_description( side : int = 0 )-> String:
	var text : String = ""

	var killed : int
	if ProgressData.killed_enemies.has(my_id) :
		killed = ProgressData.killed_enemies[my_id]
	else :
		killed = 0
	var killed_by : int
	if ProgressData.killed_by_enemies.has(my_id) :
		killed_by = ProgressData.killed_by_enemies[my_id]
	else :
		killed_by = 0

	text += _write_description_line("CODEX_ENEMY_KILLED", killed, Keys.empty_hash, side, "65c071")
	text += _write_description_line("CODEX_ENEMY_KILLED_YOU", killed_by, Keys.empty_hash, side, "fe6e68")

	return text


func _is_locked_in_codex() -> bool:
	return false


func _is_silhouette_in_codex() -> bool:
	return false


func _get_how_many_killed()-> int:
	if ProgressData.killed_enemies.has(my_id) :
		return ProgressData.killed_enemies[my_id]
	else :
		return 0


func _get_how_many_killed_by()-> int:
	if ProgressData.killed_by_enemies.has(my_id) :
		return ProgressData.killed_by_enemies[my_id]
	else :
		return 0
