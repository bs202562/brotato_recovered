class_name ScapegoatEffect
extends PetEffect

export (float) var health_boost = 1
export (float) var revive_duration

static func get_id() -> String:
	return "scapegoat"

func serialize() -> Dictionary:
	var serialized = .serialize()

	serialized.health_boost = health_boost
	serialized.revive_duration = revive_duration

	return serialized

func deserialize_and_merge(serialized: Dictionary) -> void :
	.deserialize_and_merge(serialized)

	health_boost = serialized.health_boost
	revive_duration = serialized.revive_duration
