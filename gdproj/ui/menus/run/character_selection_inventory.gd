class_name CharacterSelectionInventory
extends Inventory


func _ready():
	if ProgressData.is_dlc_available_and_active("abyssal_terrors"):
		element_size = Vector2(75, 75)
		columns = 18


func update_elements_color(current_zone_id: int) -> void :
	for element in get_children():
		if not element.item:
			continue
		var new_item = element.item.duplicate()
		assert (new_item.my_id_hash != Keys.empty_hash and new_item.my_id_hash != null)
		if current_zone_id == - 1:
			var zonesCount = ZoneService.zones.size()
			var diff_infos: Array = []
			var zone_index = 0
			for zone in zonesCount:
				diff_infos.append(ProgressData.get_character_difficulty_info(new_item.my_id_hash, zone_index))
				zone_index += 1
			var lowest_diff_value = 999
			for diff_info in diff_infos:
				if (diff_info.max_difficulty_beaten.difficulty_value < lowest_diff_value):
					lowest_diff_value = diff_info.max_difficulty_beaten.difficulty_value
			if lowest_diff_value < 0:
				new_item.tier = Tier.COMMON
			if lowest_diff_value == 0:
				new_item.tier = Tier.DANGER_0
			elif lowest_diff_value > 0:
				new_item.tier = lowest_diff_value
		else:
			var diff_info = ProgressData.get_character_difficulty_info(new_item.my_id_hash, current_zone_id)
			if diff_info.max_difficulty_beaten.difficulty_value < 0:
				new_item.tier = Tier.COMMON
			if diff_info.max_difficulty_beaten.difficulty_value == 0:
				new_item.tier = Tier.DANGER_0
			elif diff_info.max_difficulty_beaten.difficulty_value > 0:
				new_item.tier = diff_info.max_difficulty_beaten.difficulty_value
		element.item = new_item
		element.update_background_color()
