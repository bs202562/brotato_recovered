class_name CurseSceneEffectBehavior
extends SceneEffectBehavior

@export var hp_boost: int = 200
@export var damage_boost: int = 50
@export var speed_boost: int = 75
@export var curse_enemy_effect_behavior_data: Resource


const MAX_CURSE_HP_BOOST: int = 300

var _loot_alien_stats: = []


func _ready() -> void :
	var _err = _entity_spawner_ref.connect("enemy_respawned", Callable(self, "_on_EntitySpawner_enemy_respawned"))
	for group_data in _wave_manager.current_zone_data.loot_alien_groups:
		for unit_data in group_data.wave_units_data:
			_loot_alien_stats.append(_get_unit_data_stats(unit_data))


func _curse_enemy(enemy: Enemy, curse: float) -> void :
	if not is_instance_valid(enemy) or enemy.dead:
		return

	var enemy_being_cursed_effect_behavior = curse_enemy_effect_behavior_data.scene.instantiate()
	enemy.effect_behaviors.add_child(enemy_being_cursed_effect_behavior.init(enemy))

	var boost_args: = BoostArgs.new()
	boost_args.hp_boost = hp_boost + min(curse, MAX_CURSE_HP_BOOST) * 2
	boost_args.damage_boost = damage_boost
	boost_args.speed_boost = speed_boost
	boost_args.show_outline = false
	enemy.boost(boost_args)
	enemy.can_be_boosted = false


func _get_unit_data_stats(unit_data: WaveUnitData) -> Stats:
	var scene: = unit_data.unit_scene
	var scene_state: = scene.get_state()
	var node_idx: = 0
	var property_count: = scene_state.get_node_property_count(node_idx)
	for property_idx in property_count:
		if scene_state.get_node_property_name(node_idx, property_idx) == "stats":
			return scene_state.get_node_property_value(node_idx, property_idx)
	push_error("unit data %s is missing stats" % unit_data)
	return null


func _on_EntitySpawner_enemy_respawned(enemy: Enemy) -> void :
	if enemy is Boss or enemy.stats in _loot_alien_stats:
		return

	var curse = 0
	var curse_chance = 0.0
	var nb_players = RunData.get_player_count()

	for player_index in nb_players:
		var curse_stat = max(0, Utils.get_max_capped_stat(Keys.stat_curse_hash, player_index)) as int
		var player_curse_stat = curse_stat
		curse += player_curse_stat
		var player_curse_chance = min(1.0, (Utils.get_curse_factor(player_curse_stat) / 100.0 / 2.0) * (1.0 + (RunData.get_endless_factor() / 2.0)))
		curse_chance += player_curse_chance

	if (Utils.get_chance_success(curse_chance / nb_players) or DebugService.always_curse or DebugService.curse_enemy_spawn) and enemy.can_be_cursed:
		_curse_enemy(enemy, curse)
