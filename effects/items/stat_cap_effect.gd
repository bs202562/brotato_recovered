class_name StatCapEffect
extends Effect

export(String) var set_cap_to_current_stat = ""
var set_cap_to_current_stat_hash: int = Keys.empty_hash


func _generate_hashes() -> void:
	._generate_hashes()
	set_cap_to_current_stat_hash = Keys.generate_hash(set_cap_to_current_stat)


static func get_id() -> String:
	return "stat_cap"


func apply(player_index: int) -> void:
	var effects = RunData.get_player_effects(player_index)
	assert(key_hash != Keys.empty_hash)
	if set_cap_to_current_stat != "":
		assert(set_cap_to_current_stat_hash != Keys.empty_hash)
		effects[key_hash] = Utils.get_stat(set_cap_to_current_stat_hash, player_index)
	else:
		effects[key_hash] = value


func unapply(player_index: int) -> void:
	var effects = RunData.get_player_effects(player_index)
	assert(key_hash != Keys.empty_hash)
	effects[key_hash] = Utils.LARGE_NUMBER


func get_args(player_index: int) -> Array:





	var effect = RunData.get_player_effect(key_hash, player_index)
	return [str(effect if effect < Utils.LARGE_NUMBER else Utils.get_stat(set_cap_to_current_stat_hash, player_index) as int)]


func serialize() -> Dictionary:
	var serialized = .serialize()

	serialized.set_cap_to_current_stat = set_cap_to_current_stat

	return serialized


func deserialize_and_merge(serialized: Dictionary) -> void:
	.deserialize_and_merge(serialized)

	set_cap_to_current_stat = serialized.set_cap_to_current_stat
	set_cap_to_current_stat_hash = Keys.generate_hash(set_cap_to_current_stat)


func duplicate(subresources := false) -> Resource:
	var duplication = .duplicate(subresources)

	if set_cap_to_current_stat_hash == Keys.empty_hash and set_cap_to_current_stat != "":
		set_cap_to_current_stat_hash = Keys.generate_hash(set_cap_to_current_stat)

	duplication.set_cap_to_current_stat_hash = set_cap_to_current_stat_hash

	return duplication
