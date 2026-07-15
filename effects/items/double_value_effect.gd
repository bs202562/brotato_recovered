class_name DoubleValueEffect
extends Effect

enum SumStrategy { SUM_BOTH, SUM_VALUE_1, SUM_VALUE_2 }

@export var value2: int = 0
@export var sum_strategy: SumStrategy


static func get_id() -> String:
	return "double_value"


func apply(player_index: int) -> void:
	if key == "": return

	assert(key_hash != Keys.empty_hash)
	var effects = RunData.get_player_effects(player_index)
	if storage_method == StorageMethod.KEY_VALUE:
		effects[custom_key_hash].push_back([key_hash, value, value2])
	elif storage_method == StorageMethod.SUM:
		var applied := false
		for effect in effects[key_hash]:
			match sum_strategy:
				SumStrategy.SUM_BOTH:
					effect[0] += value
					effect[1] += value2
					applied = true
				SumStrategy.SUM_VALUE_1:
					if effect[1] == value2:
						effect[0] += value
						applied = true
				SumStrategy.SUM_VALUE_2:
					if effect[0] == value:
						effect[1] += value2
						applied = true

		if not applied:
			effects[key_hash].push_back([value, value2])
	else:
		effects[key_hash].push_back([value, value2])


func unapply(player_index: int) -> void:
	if key == "": return
	assert(key_hash != Keys.empty_hash)

	var effects = RunData.get_player_effects(player_index)
	if storage_method == StorageMethod.KEY_VALUE:
		effects[custom_key_hash].erase([key_hash, value, value2])
	elif storage_method == StorageMethod.SUM:
		for effect in effects[key_hash]:
			match sum_strategy:
				SumStrategy.SUM_BOTH:
					effect[0] -= value
					effect[1] -= value2
					if effect[0] == 0 and effect[1] == 0:
						effects[key_hash].erase(effect)
				SumStrategy.SUM_VALUE_1:
					if effect[1] == value2:
						effect[0] -= value
					if effect[0] == 0:
						effects[key_hash].erase(effect)
				SumStrategy.SUM_VALUE_2:
					if effect[0] == value:
						effect[1] -= value2
					if effect[1] == 0:
						effects[key_hash].erase(effect)

			if effect == [0, 0]:
				effects.erase(effect)
	else:
		effects[key_hash].erase([value, value2])


func get_args(_player_index: int) -> Array:
	return [str(value), tr(key.to_upper()), str(value2)]


func serialize() -> Dictionary:
	var serialized = super.serialize()

	serialized.value2 = value2
	serialized.sum_strategy = sum_strategy

	return serialized


func deserialize_and_merge(serialized: Dictionary) -> void:
	super.deserialize_and_merge(serialized)

	value2 = serialized.value2
	sum_strategy = serialized.get(sum_strategy, SumStrategy.SUM_VALUE_1)
