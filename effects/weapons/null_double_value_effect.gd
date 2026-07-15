class_name NullDoubleValueEffect
extends NullEffect

@export var value2: float = 0.0


static func get_id() -> String:
	return "null_double_value"


func get_args(_player_index: int) -> Array:
	return [str(value), tr(key.to_upper()), str(value2)]


func serialize() -> Dictionary:
	var serialized = super.serialize()

	serialized.value2 = value2

	return serialized


func deserialize_and_merge(serialized: Dictionary) -> void :
	super.deserialize_and_merge(serialized)

	value2 = serialized.value2
