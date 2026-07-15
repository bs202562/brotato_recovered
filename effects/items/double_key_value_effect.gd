class_name DoubleKeyValueEffect
extends Effect

@export var key2 := ""
@export var value2 := 0

var key2_hash: int = Keys.empty_hash


func _generate_hashes() -> void:
	super._generate_hashes()
	key2_hash = Keys.generate_hash(key2)


static func get_id() -> String:
	return "double_key_value"


func apply(player_index: int) -> void:
	var effects = RunData.get_player_effect(custom_key_hash, player_index)
	for existing_effect in effects:
		if existing_effect[0] == key_hash and existing_effect[2] == key2_hash and existing_effect[3] == value2:
			existing_effect[1] += value
			return
	effects.push_back([key_hash, value, key2_hash, value2])


func unapply(player_index: int) -> void:
	var effects = RunData.get_player_effect(custom_key_hash, player_index)
	for i in effects.size():
		var existing_effect = effects[i]
		if existing_effect[0] == key_hash and existing_effect[2] == key2_hash and existing_effect[3] == value2:
			existing_effect[1] -= value
			if existing_effect[1] == 0:
				effects.remove_at(i)
			return


func get_args(_player_index: int) -> Array:
	return [str(value), tr(key.to_upper()), str(value2), tr(key2.to_upper())]


func serialize() -> Dictionary:
	var serialized = super.serialize()
	serialized.key2 = key2
	serialized.value2 = value2
	return serialized


func deserialize_and_merge(serialized: Dictionary) -> void:
	super.deserialize_and_merge(serialized)
	key2 = serialized.key2
	key2_hash = Keys.generate_hash(key2)
	value2 = serialized.value2


func duplicate(subresources := false) -> Resource:
	var duplication = super.duplicate(subresources)

	if key2_hash == Keys.empty_hash and key2 != "":
		key2_hash = Keys.generate_hash(key2)

	duplication.key2_hash = key2_hash

	return duplication
