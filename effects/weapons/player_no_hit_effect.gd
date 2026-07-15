class_name PlayerNoHitEffect
extends NullEffect

export (int) var interval: = 5

static func get_id() -> String:
	return "effect_no_hit_boost"

func get_args(player_index: int) -> Array:
	return [str(value), str(interval)]

func serialize() -> Dictionary:
	var serialized = .serialize()
	serialized.interval = interval
	return serialized

func deserialize_and_merge(serialized: Dictionary) -> void :
	.deserialize_and_merge(serialized)
	interval = serialized.interval





