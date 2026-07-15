class_name BonkDogEffect
extends PetEffect

export (Resource) var weapon_stats
export (Resource) var explosion_effect

static func get_id() -> String:
	return "bonk_dog"

func get_args(player_index: int) -> Array:
	var args: = WeaponServiceInitStatsArgs.new()
	var _current_weapon_stats = WeaponService.init_melee_pet_stats(weapon_stats, player_index, args)

	var scaling_stats_text = WeaponService.get_scaling_stats_icon_text(_current_weapon_stats.scaling_stats)

	args.effects.push_back(explosion_effect)
	var _current_explosion_weapon_stats = WeaponService.init_base_stats(explosion_effect.stats, player_index, args, false, false, true)
	var explosion_scaling_stats_text = WeaponService.get_scaling_stats_icon_text(_current_explosion_weapon_stats.scaling_stats)

	return [str(_current_weapon_stats.damage), 
	scaling_stats_text, 
	str(stepify(explosion_effect.stats.cooldown / 60.0, 0.1)), 
	str(_current_explosion_weapon_stats.damage), 
	explosion_scaling_stats_text]

func serialize() -> Dictionary:
	var serialized = .serialize()

	serialized.weapon_stats = weapon_stats.serialize()
	serialized.explosion_effect = explosion_effect.serialize()

	return serialized

func deserialize_and_merge(serialized: Dictionary) -> void :
	.deserialize_and_merge(serialized)

	var stats = MeleeWeaponStats.new()
	stats.deserialize_and_merge(serialized.weapon_stats)
	weapon_stats = stats

	var stats_2 = ItemExplodingEffect.new()
	stats_2.deserialize_and_merge(serialized.explosion_effect)
	explosion_effect = stats_2
