class_name DocMothEffect
extends PetEffect

export (float) var boost_zone_scale = 1

static func get_id() -> String:
	return "doc_moth"

func serialize() -> Dictionary:
	var serialized = .serialize()

	serialized.boost_zone_scale = boost_zone_scale

	return serialized

func deserialize_and_merge(serialized: Dictionary) -> void :
	.deserialize_and_merge(serialized)

	boost_zone_scale = serialized.boost_zone_scale

