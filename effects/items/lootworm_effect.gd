class_name LootwormEffect
extends PetEffect

@export var double_chance: float

static func get_id() -> String:
	return "lootworm"

func apply(player_index: int) -> void :
	super.apply(player_index)
	var effects = RunData.get_player_effects(player_index)
	effects[Keys.stat_has_lootworm_hash] = 1
	Utils.reset_stat_cache(player_index)

func get_args(player_index: int) -> Array:
	return [str(double_chance * 100)]

func serialize() -> Dictionary:
	var serialized = super.serialize()

	serialized.double_chance = double_chance

	return serialized

func deserialize_and_merge(serialized: Dictionary) -> void :
	super.deserialize_and_merge(serialized)

	double_chance = serialized.double_chance
