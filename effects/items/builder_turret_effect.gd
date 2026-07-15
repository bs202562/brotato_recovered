class_name BuilderTurretEffect
extends TurretEffect

var _init_stats_args_builder: = WeaponServiceInitStatsArgs.new()

static func get_id() -> String:
	return "builder_turret"


func get_text(player_index: int, colored: bool = true) -> String:
	var text = ""

	var structure_range = RunData.get_player_effect(Keys.structure_range_hash, player_index)
	var level = BuilderTurret.get_level(structure_range)
	var best_weapon = BuilderTurret.get_best_ranged_weapon(player_index)

	if best_weapon:
		best_weapon = best_weapon.duplicate()
		var stats = BuilderTurret.apply_scaling(best_weapon.stats, level)
		var effects = BuilderTurret.update_effects(best_weapon.effects)
		stats.cooldown = clamp(stats.cooldown, BuilderTurret.MIN_BASE_WEAPON_CD, BuilderTurret.MAX_BASE_WEAPON_CD) as int

		_init_stats_args_builder.effects = effects
		best_weapon.effects = effects
		var final_stats = WeaponService.init_structure_stats(stats, player_index, _init_stats_args_builder)
		final_stats.cooldown = WeaponService.apply_structure_attack_speed_effects(final_stats.cooldown, player_index)

		text += final_stats.get_text(stats, player_index, effects) + "\n"

		if effects.size() > 0:
			text += best_weapon.get_effects_text(player_index, false) + "\n"

	text += super.get_text(player_index, colored)

	return text


func get_args(player_index: int) -> Array:
	var args = super.get_args(player_index)

	var best_weapon = BuilderTurret.get_best_ranged_weapon(player_index)

	if best_weapon:
		args.push_back(tr(best_weapon.name.to_upper()))
	else:
		args.push_back("-")

	return args
