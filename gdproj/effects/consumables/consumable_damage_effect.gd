class_name ConsumableDamageEffect
extends NullEffect


func apply(player_index: int, from = null) -> void :
	var damage_value = value + RunData.get_player_effect(Keys.consumable_heal_hash, player_index)
	if damage_value > 0:
		RunData.emit_signal("damage_effect", damage_value, player_index, false, false, from)
