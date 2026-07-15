class_name ProjectileEffect
extends Effect

@export var weapon_stats: Resource
@export var auto_target_enemy: bool = false
@export var cooldown: int = -1


static func get_id() -> String:
	return "projectile"


func apply(player_index: int) -> void:
	var effect: Array = RunData.get_player_effect(key_hash, player_index)
	if effect.is_empty():
		effect.append_array([value, weapon_stats.duplicate(), auto_target_enemy, cooldown])
	else:
		var existing_proj_count = effect[0]
		var total_proj_count = existing_proj_count + value
		effect[0] = total_proj_count
		effect[1].scaling_stats = _merge_scaling_stats(existing_proj_count, effect[1].scaling_stats)


func unapply(player_index: int) -> void:
	var effect: Array = RunData.get_player_effect(key_hash, player_index)
	assert(not effect.is_empty(), "Can't unapply non existing effect")

	var existing_proj_count = effect[0]
	var total_proj_count = existing_proj_count - value
	effect[0] = total_proj_count
	effect[1].scaling_stats = _merge_scaling_stats(existing_proj_count, effect[1].scaling_stats, true)


func _merge_scaling_stats(existing_proj_count: int, existing_scaling: Array, subtract := false) -> Array:

	var duplicated_scaling = existing_scaling.duplicate(true)
	for scaling_stat in weapon_stats.scaling_stats:
		var found = false
		for existing_scaling_stat in duplicated_scaling:
			if scaling_stat[0] == existing_scaling_stat[0]:
				found = true
				if subtract:
					existing_scaling_stat[1] = (existing_scaling_stat[1] * existing_proj_count - scaling_stat[1] * value) / (existing_proj_count - value)
				else:
					existing_scaling_stat[1] = (existing_scaling_stat[1] * existing_proj_count + scaling_stat[1] * value) / (existing_proj_count + value)
				break

		if not found:
			duplicated_scaling.append(scaling_stat)

	return duplicated_scaling


func get_args(player_index: int) -> Array:
	var current_stats = WeaponService.init_ranged_stats(weapon_stats, player_index, true)
	var scaling_text = WeaponService.get_scaling_stats_icon_text(weapon_stats.scaling_stats)
	return [str(value), str(current_stats.damage), str(current_stats.bounce + 1), scaling_text, str(cooldown)]


func serialize() -> Dictionary:
	var serialized = super.serialize()

	if weapon_stats != null:
		serialized.weapon_stats = weapon_stats.serialize()

	serialized.auto_target_enemy = auto_target_enemy
	serialized.cooldown = cooldown

	return serialized


func deserialize_and_merge(serialized: Dictionary) -> void:
	super.deserialize_and_merge(serialized)

	if serialized.has("weapon_stats"):
		var data = RangedWeaponStats.new()
		data.deserialize_and_merge(serialized.weapon_stats)
		weapon_stats = data

	auto_target_enemy = serialized.auto_target_enemy
	cooldown = serialized.cooldown
