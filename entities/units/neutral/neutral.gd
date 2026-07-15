class_name Neutral
extends Unit

@export var number_of_hits_before_dying: int = 8

var current_number_of_hits = 0


func init(zone_min_pos: Vector2, zone_max_pos: Vector2, players_ref: Array = [], entity_spawner_ref = null) -> void :
	super.init(zone_min_pos, zone_max_pos, players_ref, entity_spawner_ref)
	init_current_stats()


func respawn() -> void :
	super.respawn()
	init_current_stats()
	current_number_of_hits = 0


func take_damage(value: int, args: TakeDamageArgs) -> Array:
	var result = super.take_damage(value, args)

	current_number_of_hits += 1

	if dead:
		return result
	if args.hitbox and args.hitbox.from and ( not (args.hitbox.from is Object) or (args.hitbox.from is Object and ( not "player_index" in args.hitbox.from or args.hitbox.from.player_index == - 1))):
		return result

	if (current_number_of_hits >= number_of_hits_before_dying
		or (args.hitbox and is_instance_valid(args.hitbox) and RunData.get_player_effect_bool(Keys.one_shot_trees_hash, args.hitbox.from.player_index))
		or DebugService.one_shot_enemies):
		die(_die_args_unit)

	return result


func die(_args = Utils.default_die_args) -> void :
	super.die()
	ProgressData.increment_stat("trees_killed")
	
	
