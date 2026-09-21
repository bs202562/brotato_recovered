class_name BlazemanderEffect
extends PetEffect

export (Resource) var weapon_stats
export (Resource) var ranged_weapon_stats
export (Resource) var burning_data = null

static func get_id() -> String:
	return "blazemander"

func get_args(player_index: int) -> Array:
	var args: = WeaponServiceInitStatsArgs.new()
	var _current_weapon_stats = WeaponService.init_melee_pet_stats(weapon_stats, player_index, args)
	var _current_ranged_weapon_stats = WeaponService.init_ranged_pet_stats(ranged_weapon_stats, player_index, false, args)
	var scaling_stats: String = WeaponService.get_scaling_stats_icon_text(_current_weapon_stats.scaling_stats)

	var current_burning_data: BurningData = WeaponService.init_burning_data(burning_data, player_index, false, true)
	var burning_scaling_stats: String = WeaponService.get_scaling_stats_icon_text(current_burning_data.scaling_stats)

	return [str(_current_weapon_stats.damage), 
	scaling_stats, 
	str(current_burning_data.duration), 
	str(current_burning_data.damage), 
	burning_scaling_stats, 
	str(stepify(_current_ranged_weapon_stats.cooldown / 60.0, 0.1)), 
	str(_current_ranged_weapon_stats.damage), 
	WeaponService.get_scaling_stats_icon_text(_current_ranged_weapon_stats.scaling_stats)]

func serialize() -> Dictionary:
	var serialized = .serialize()

	serialized.weapon_stats = weapon_stats.serialize()
	serialized.ranged_weapon_stats = ranged_weapon_stats.serialize()
	serialized.burning_data = burning_data.serialize()

	return serialized

func deserialize_and_merge(serialized: Dictionary) -> void :
	.deserialize_and_merge(serialized)

	var stats = MeleeWeaponStats.new()
	stats.deserialize_and_merge(serialized.weapon_stats)
	weapon_stats = stats

	var ranged_stats = RangedWeaponStats.new()
	ranged_stats.deserialize_and_merge(serialized.ranged_weapon_stats)
	ranged_weapon_stats = ranged_stats

	var burning_stats = BurningData.new()
	burning_stats.deserialize_and_merge(serialized.burning_data)
	burning_data = burning_stats
