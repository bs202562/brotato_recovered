class_name CurseEnemyEffectBehavior
extends EnemyEffectBehavior

const CURSED_ENEMIES_BONUS_GOLD: = 0.33


func init(parent: Enemy) -> EnemyEffectBehavior:
	var _self = .init(parent)
	_parent.add_outline(Utils.CURSE_COLOR)
	return self

func get_bonus_damage(hitbox: Hitbox, from_player_index: int) -> int:
	var bonus_damage: = 0
	var weapon_class_bonus_dmg_effects = RunData.get_player_effect(Keys.bonus_weapon_class_damage_against_cursed_enemies_hash, from_player_index)

	if from_player_index >= 0 and hitbox and is_instance_valid(hitbox.from) and "weapon_sets" in hitbox.from and weapon_class_bonus_dmg_effects.size() > 0:
		for weapon_class_bonus_dmg_effect in weapon_class_bonus_dmg_effects:
			for set in hitbox.from.weapon_sets:
				assert (weapon_class_bonus_dmg_effect[0] is int)
				if set.my_id == Keys.hash_to_string[weapon_class_bonus_dmg_effect[0]].replace("weapon_class_", "set_"):
					bonus_damage += weapon_class_bonus_dmg_effect[1]

	return bonus_damage


func get_gold_value_modifier() -> float:
	return CURSED_ENEMIES_BONUS_GOLD


func on_taken_damage(args: TakeDamageArgs) -> int:

	if args.from_player_index == - 1 or _parent.current_stats.health > 0:
		return HitType.NORMAL

	var gold_on_cursed_enemy_kill = RunData.get_player_effect(Keys.gold_on_cursed_enemy_kill_hash, args.from_player_index)

	if gold_on_cursed_enemy_kill > 0:
		RunData.add_gold(gold_on_cursed_enemy_kill, args.from_player_index)
		
		RunData.add_tracked_value(args.from_player_index, Keys.item_black_flag_hash, gold_on_cursed_enemy_kill)

		return HitType.GOLD_ON_CURSED_KILL

	return HitType.NORMAL

func on_death(_die_args: Entity.DieArgs) -> void :
	_parent.can_be_boosted = true
