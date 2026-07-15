class_name DocMothEffect
extends PetEffect

@export var boost_zone_scale: float = 1

static func get_id() -> String:
	return "doc_moth"

func serialize() -> Dictionary:
	var serialized = super.serialize()

	serialized.boost_zone_scale = boost_zone_scale

	return serialized

func deserialize_and_merge(serialized: Dictionary) -> void :
	super.deserialize_and_merge(serialized)

	boost_zone_scale = serialized.boost_zone_scale

