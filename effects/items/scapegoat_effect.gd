class_name ScapegoatEffect
extends PetEffect

@export var health_boost: float = 1
@export var revive_duration: float

static func get_id() -> String:
	return "scapegoat"

func serialize() -> Dictionary:
	var serialized = super.serialize()

	serialized.health_boost = health_boost
	serialized.revive_duration = revive_duration

	return serialized

func deserialize_and_merge(serialized: Dictionary) -> void :
	super.deserialize_and_merge(serialized)

	health_boost = serialized.health_boost
	revive_duration = serialized.revive_duration
