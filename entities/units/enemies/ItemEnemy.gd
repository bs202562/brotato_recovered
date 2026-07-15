extends ItemEntity
class_name ItemEnemy

@export var is_boss: bool = false
@export var is_elite: bool = false

func _get_entity_description(side: int = 0, hide_if_non_unlock_in_codex: bool = false) -> String:
	if _is_locked_in_codex() and hide_if_non_unlock_in_codex:
		if side <= 0:
			var quantity: int = unlock_codex_descr_after_get_it - _get_how_many_killed()
			return Text.text("CODEX_NEED_TO_KILL_MORE", [str(quantity)])
		else:
			return ("")

	var text: String = ""

	text += _write_description_line("CODEX_ENEMY_ARMOR", stats.armor, Keys.stat_armor_hash, side)
	text += _write_description_line("CODEX_ENEMY_ARMOR_GAIN_PER_WAVE", stats.armor_increase_each_wave, Keys.stat_armor_hash, side)

	return text


func _get_entity_player_stats_description(side: int = 0) -> String:
	var text: String = ""

	var killed: int
	if ProgressData.killed_enemies.has(my_id_hash):
		killed = ProgressData.killed_enemies[my_id_hash]
	else:
		killed = 0
	var killed_by: int
	if ProgressData.killed_by_enemies.has(my_id_hash):
		killed_by = ProgressData.killed_by_enemies[my_id_hash]
	else:
		killed_by = 0

	text += _write_description_line("CODEX_ENEMY_KILLED", killed, Keys.empty_hash, side, "65c071")
	text += _write_description_line("CODEX_ENEMY_KILLED_YOU", killed_by, Keys.empty_hash, side, "fe6e68")

	return text

func _get_how_many_killed() -> int:
	if ProgressData.killed_enemies.has(my_id_hash):
		return ProgressData.killed_enemies[my_id_hash]
	else:
		return 0


func _get_how_many_killed_by() -> int:
	if ProgressData.killed_by_enemies.has(my_id_hash):
		return ProgressData.killed_by_enemies[my_id_hash]
	else:
		return 0

func _is_locked_in_codex() -> bool:
	return _get_how_many_killed() < unlock_codex_descr_after_get_it


func _is_silhouette_in_codex() -> bool:
	return _get_how_many_killed() < 1
