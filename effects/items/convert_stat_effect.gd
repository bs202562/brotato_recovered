class_name ConvertStatEffect
extends Effect

@export var pct_converted: float = 1.0
@export var to_stat: String = "stat_max_hp"
@export var to_value: int = 1

var to_stat_hash: int = Keys.stat_max_hp_hash

static func get_id() -> String:
	return "convert_stat"


func _generate_hashes() -> void:
	super._generate_hashes()
	to_stat_hash = Keys.generate_hash(to_stat)


func apply(player_index: int) -> void:


	RunData.get_player_effects(player_index)[custom_key_hash].push_back(self)


func unapply(player_index: int) -> void:


	RunData.get_player_effects(player_index)[custom_key_hash].erase(self)


func get_args(_player_index: int) -> Array:
	return [str(pct_converted), tr(key.to_upper()), tr(to_stat.to_upper()), str(value), str(to_value)]


func serialize() -> Dictionary:
	var serialized = super.serialize()

	serialized.pct_converted = pct_converted
	serialized.to_stat = to_stat
	serialized.to_value = to_value

	return serialized


func deserialize_and_merge(serialized: Dictionary) -> void:
	super.deserialize_and_merge(serialized)

	pct_converted = serialized.pct_converted
	to_stat = serialized.to_stat
	to_stat_hash = Keys.generate_hash(to_stat)
	to_value = serialized.to_value as int


func duplicate(subresources := false) -> Resource:
	var duplication = super.duplicate(subresources)

	if to_stat_hash == Keys.empty_hash and to_stat != "":
		to_stat_hash = Keys.generate_hash(to_stat)

	duplication.to_stat_hash = to_stat_hash

	return duplication
