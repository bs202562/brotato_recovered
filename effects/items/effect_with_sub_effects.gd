class_name EffectWithSubEffects
extends Effect

@export var sub_effects: Array = [] # (Array, Resource)


static func get_id() -> String:
	return "effect_with_sub_effects"


func apply(player_index: int) -> void:
	RunData.get_player_effect(key_hash, player_index).append(self)


func unapply(player_index: int) -> void:
	RunData.get_player_effect(key_hash, player_index).erase(self)



func get_args(player_index: int) -> Array:
	var args = super.get_args(player_index)

	for sub_effect in sub_effects:
		args.append_array(sub_effect.get_args(player_index))

	return args


func serialize() -> Dictionary:
	var serialized = super.serialize()

	var serialized_sub_effects := []
	for sub_effect in sub_effects:
		serialized_sub_effects.append(sub_effect.serialize())
	serialized.sub_effects = serialized_sub_effects
	return serialized


func deserialize_and_merge(serialized: Dictionary) -> void:
	super.deserialize_and_merge(serialized)

	for serialized_sub_effect in serialized.sub_effects:
		var sub_effect := Effect.new()
		sub_effect.deserialize_and_merge(serialized_sub_effect)
		sub_effects.append(sub_effect)
