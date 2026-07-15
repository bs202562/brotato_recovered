extends ItemEntity
class_name ItemPet

export (Resource) var item_drop


func _get_entity_player_stats_description(side: int = 0) -> String:
	return _write_description_line("CODEX_PET_OBTAINED", str(_get_how_many_killed()), Keys.empty_hash, side, "65c071")


func _get_how_many_killed() -> int:
	if ProgressData.items_bought.has(item_drop.my_id_hash):
		return ProgressData.items_bought[item_drop.my_id_hash]
	else:
		return 0

func _is_silhouette_in_codex() -> bool:
	return _get_how_many_killed() < 1
