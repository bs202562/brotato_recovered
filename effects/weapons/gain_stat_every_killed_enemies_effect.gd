class_name GainStatEveryKilledEnemiesEffect
extends NullEffect

@export var stat: String = ""
@export var stat_nb: int = 1
var stat_hash: int = Keys.empty_hash


func _generate_hashes() -> void :
	super._generate_hashes()
	stat_hash = Keys.generate_hash(stat)


static func get_id() -> String:
	return "weapon_gain_stat_every_killed_enemies"


func get_args(_player_index: int) -> Array:
	return [str(stat_nb), tr(stat.to_upper()), str(value)]


func serialize() -> Dictionary:
	var serialized = super.serialize()

	serialized.stat = stat
	serialized.stat_nb = stat_nb

	return serialized


func deserialize_and_merge(serialized: Dictionary) -> void :
	super.deserialize_and_merge(serialized)

	stat = serialized.stat
	stat_hash = Keys.generate_hash(stat)
	stat_nb = serialized.stat_nb as int
