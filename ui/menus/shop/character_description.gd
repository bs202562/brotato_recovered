class_name CharacterDescription
extends ItemDescription


func set_item(item_data: ItemParentData, player_index: int, item_count: = 1) -> void :
	item = item_data
	_player_index = player_index

	
	
	var effects: Array = item_data.effects.duplicate()
	for effect in item_data.effects:
		if (effect.custom_key == "starting_weapon"
		or effect.custom_key == "starting_item"
		or effect.custom_key == "cursed_starting_item"
		or effect.custom_key == "cursed_starting_weapon"):
			effects.erase(effect)

	_generate_description_effects(player_index, effects, true)
	get_effects().visible = get_effects().get_child_count() > 0


func set_custom_data(name: String, icon: Resource) -> void :
	get_effects().hide()
	item = null
