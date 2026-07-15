class_name GainStatForKilledEnemiesWhileBurning
extends DoubleValueEffect

@export var value3: int = 0

static func get_id() -> String:
	return "gain_stat_for_kill_enemies_while_burning"


func apply(player_index: int) -> void :
	if key == "": return

	var effects = RunData.get_player_effects(player_index)
	if storage_method == StorageMethod.KEY_VALUE:
		effects[custom_key_hash].push_back([key_hash, value, value2, value3, 0, 0])
	elif storage_method == StorageMethod.SUM:
		print("GainStatForKilledEnemiesWhileBurning - NO IMPLEMENTED")
	else:
		effects[key].push_back([value, value2, value3, 0, 0])


func unapply(player_index: int) -> void :
	if key == "": return

	var effects = RunData.get_player_effects(player_index)
	if storage_method == StorageMethod.KEY_VALUE:
		for effect in effects[custom_key_hash]:
			effect[4] = 0
			effect[5] = 0
		effects[custom_key_hash].erase([key_hash, value, value2, value3, 0, 0])
	elif storage_method == StorageMethod.SUM:
		print("GainStatForKilledEnemiesWhileBurning - NO IMPLEMENTED")
	else:
		for effect in effects[custom_key_hash]:
			effect[3] = 0
			effect[4] = 0
		effects[key_hash].erase([value, value2, value3, 0, 0])


func get_args(_player_index: int) -> Array:
	return [str(value), tr(key.to_upper()), str(value2), str(value3)]


func serialize() -> Dictionary:
	var serialized = super.serialize()

	serialized.value3 = value3

	return serialized


func deserialize_and_merge(serialized: Dictionary) -> void :
	super.deserialize_and_merge(serialized)

	value3 = serialized.value3
