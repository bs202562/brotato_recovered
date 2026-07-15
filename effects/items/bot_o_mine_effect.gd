class_name BotOMineEffect
extends PetEffect

export (Resource) var weapon_stats
export (Resource) var landmine_effect_stat

static func get_id() -> String:
	return "bot_o_mine"

func get_args(player_index: int) -> Array:
	var args: = WeaponServiceInitStatsArgs.new()
	var _current_weapon_stats = WeaponService.init_structure_pet_stats(weapon_stats, player_index, args)
	var scaling_stats_text = WeaponService.get_scaling_stats_icon_text(_current_weapon_stats.scaling_stats)

	var spawn_cd = WeaponService.apply_structure_attack_speed_effects(landmine_effect_stat.spawn_cooldown, player_index)

	var landmine_args: = WeaponServiceInitStatsArgs.new()
	landmine_args.effects = landmine_effect_stat.effects
	var landmine_stats = WeaponService.init_structure_pet_stats(landmine_effect_stat.stats, player_index, landmine_args)
	var landmine_scaling_stats_text = WeaponService.get_scaling_stats_icon_text(landmine_stats.scaling_stats)

	return [str(_current_weapon_stats.damage), 
	scaling_stats_text, 
	str(stepify(spawn_cd / 60.0, 0.1)), 
	str(landmine_stats.damage), 
	landmine_scaling_stats_text]

func serialize() -> Dictionary:
	var serialized = .serialize()

	serialized.weapon_stats = weapon_stats.serialize()
	serialized.landmine_effect_stat = landmine_effect_stat.serialize()

	return serialized

func deserialize_and_merge(serialized: Dictionary) -> void :
	.deserialize_and_merge(serialized)

	var stats = RangedWeaponStats.new()
	stats.deserialize_and_merge(serialized.weapon_stats)
	weapon_stats = stats

	var landmine_stat = StructureEffect.new()
	landmine_stat.deserialize_and_merge(serialized.landmine_effect_stat)
	landmine_effect_stat = landmine_stat
