class_name CatlingGunEffect
extends PetEffect

@export var weapon_stats: Resource

static func get_id() -> String:
	return "catling_gun"

func get_args(player_index: int) -> Array:
	var args: = WeaponServiceInitStatsArgs.new()
	var _current_weapon_stats = WeaponService.init_ranged_pet_stats(weapon_stats, player_index, false, args)
	var scaling_stats_text = WeaponService.get_scaling_stats_icon_text(_current_weapon_stats.scaling_stats)

	return [str(_current_weapon_stats.damage), scaling_stats_text]

func serialize() -> Dictionary:
	var serialized = super.serialize()

	serialized.weapon_stats = weapon_stats.serialize()

	return serialized

func deserialize_and_merge(serialized: Dictionary) -> void :
	super.deserialize_and_merge(serialized)

	var stats = RangedWeaponStats.new()
	stats.deserialize_and_merge(serialized.weapon_stats)
	weapon_stats = stats
