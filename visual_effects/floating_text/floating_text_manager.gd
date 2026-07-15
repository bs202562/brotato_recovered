class_name FloatingTextManager
extends FloatingTextManagerBase

var players: = []
var players_add_stats_count: = []
var _cleaning_up: = false

var offset = Vector2(0, 30)

func _ready() -> void :
	super._ready() # 4.x 移植: Godot 3 自动调用父类虚函数，4.x 需显式调用（_ready 为基类优先）
	var _stat_add_error = RunData.connect("stat_added", Callable(self, "on_stat_added"))
	var _stat_remove_error = RunData.connect("stat_removed", Callable(self, "on_stat_removed"))


func on_enemy_state_changed(unit: Unit) -> void :
	display("MUTATION", unit.global_position)


func on_levelled_up(player_index: int) -> void :
	var player: Player = players[player_index]
	if not player.dead:
		display("LEVEL_UP", player.global_position)


func on_harvested(value: int, player_index: int) -> void :
	var player: Player = players[player_index]

	if not player.dead:
		var pos = player.global_position - players_add_stats_count[player_index] * offset
		players_add_stats_count[player_index] += 1

		display_icon(value, ItemService.get_icon(Keys.icon_harvesting_hash), harvest_pos_sounds, harvest_neg_sounds, pos, Vector2(0, 50), player_index)


func on_stat_added(stat: int, value: int, db_mod: float, player_index: int, pos_sounds: Array = stat_pos_sounds, neg_sounds: Array = stat_neg_sounds) -> void :
	var player: Player = players[player_index]
	if stat in ignored_stats:
		return

	if not player.dead:
		var pos = player.global_position - Vector2(0, 50) - players_add_stats_count[player_index] * offset
		players_add_stats_count[player_index] += 1

		display_icon(value, ItemService.get_stat_icon(stat), pos_sounds, neg_sounds, pos, direction, db_mod, player_index, value > 0)

func on_stat_removed(stat: int, value: int, db_mod: float, player_index: int, pos_sounds: Array = stat_pos_sounds, neg_sounds: Array = stat_neg_sounds) -> void :
	var player: Player = players[player_index]
	if not player.dead:
		on_stat_added(stat, - value, db_mod, player_index, pos_sounds, neg_sounds)


func _on_player_healed(value: int, player_index: int) -> void :
	if value > 0:
		display("+" + str(value), players[player_index].global_position, Color(ProgressData.settings.color_positive), null, duration, false, direction, false)


func on_turret_stat_added(stat: int, value: int, db_mod: float, turret_position: Vector2, pos_sounds: Array = stat_pos_sounds, neg_sounds: Array = stat_neg_sounds) -> void :
	if stat in ignored_stats:
		return

	display_icon(value, ItemService.get_stat_icon(stat), pos_sounds, neg_sounds, turret_position - Vector2(0, 50), direction, db_mod)


func _on_unit_took_damage(unit: Unit, value: int, _knockback_direction: Vector2, is_crit: bool, is_dodge: bool, is_protected: bool, armor_did_something: bool, _args: TakeDamageArgs, hit_type: int, is_one_shot: bool) -> void :
	if not ProgressData.settings.damage_display:
			return

	var color: Color = Color.WHITE
	var text = str(value)
	var always_display = false
	var need_translate = false

	if unit is Player:
		always_display = true
		if value > 0:
			color = ProgressData.settings.color_negative
			text = "-" + text
		elif is_dodge:
			text = "DODGE"
			need_translate = true
		elif is_protected:
			text = "NULLIFIED"
			need_translate = true
	elif is_crit:
		color = Color.YELLOW
	elif is_one_shot:
		always_display = true
		text = "ONE_SHOT"
		need_translate = true
	elif armor_did_something:
		color = Color.GRAY


	var icon = null if hit_type == HitType.NORMAL else get_special_hit_icon(hit_type)

	display(text, unit.global_position, color, icon, duration, always_display, direction, need_translate)


func get_special_hit_icon(special_hit_type: int) -> Resource:
	if special_hit_type == HitType.GOLD_ON_CURSED_KILL:
		return ItemService.get_icon(Keys.icon_gold_on_cursed_kill_hash)

	return ItemService.get_icon(Keys.icon_gold_on_crit_kill_hash)


func on_gold_picked_up(gold: Node, _player_index: int) -> void :
	if not _cleaning_up and gold.boosted > 1:
		display("x" + str(gold.boosted), gold.global_position, Color(ProgressData.settings.color_positive), null, duration, false, direction, false)


func clean_up_room() -> void :
	_cleaning_up = true


func get_floating_text() -> FloatingText:
	var main: Main = Utils.get_scene_node()

	var instance: FloatingText = main.get_node_from_pool(floating_text_pool_id, main._floating_texts)
	if instance == null:
		instance = create_floating_text()
	return instance


func on_floating_text_available(instance: FloatingText) -> void :
	super.on_floating_text_available(instance)

	if instance.has_theme_icon and instance.player_index > - 1:
		players_add_stats_count[instance.player_index] -= 1

	instance.has_theme_icon = false
	instance.player_index = - 1
	var main: Main = Utils.get_scene_node()
	main.add_node_to_pool(instance, floating_text_pool_id)
