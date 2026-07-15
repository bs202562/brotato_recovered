class_name SwapMaxMinStatEffect
extends Effect

var stats_swapped: Array = []
var has_been_applied: bool = false


static func get_id() -> String:
	return "swap_max_min_stat"


func apply(player_index: int) -> void:
	has_been_applied = true
	stats_swapped = _find_min_max_stat_keys(player_index)

	var min_stat_key: int = stats_swapped[0]
	var max_stat_key: int = stats_swapped[1]

	assert(min_stat_key is int)
	assert(max_stat_key is int)

	var effects = RunData.get_player_effects(player_index)

	var min_stat_temp = TempStats.get_stat(min_stat_key, player_index)
	var max_stat_temp = TempStats.get_stat(max_stat_key, player_index)

	var min_stat_linked = LinkedStats.get_stat(min_stat_key, player_index)
	var max_stat_linked = LinkedStats.get_stat(max_stat_key, player_index)

	var min_stat_gain = RunData.get_stat_gain(min_stat_key, player_index)
	var max_stat_gain = RunData.get_stat_gain(max_stat_key, player_index)

	var min_stat_value = Utils.get_stat(min_stat_key, player_index)
	var max_stat_value = Utils.get_stat(max_stat_key, player_index)

	var new_min_permanent = (
		(max_stat_value - min_stat_temp - min_stat_linked)
		/ min_stat_gain
	)

	var new_max_permanent = (
		(min_stat_value - max_stat_temp - max_stat_linked)
		/ max_stat_gain
	)

	effects[min_stat_key] = new_min_permanent
	effects[max_stat_key] = new_max_permanent

	Utils.reset_stat_cache(player_index)


func unapply(_player_index: int) -> void:
	pass


func get_args(player_index: int) -> Array:
	if has_been_applied == false:
		stats_swapped = _find_min_max_stat_keys(player_index)
	return [tr(Keys.hash_to_string[stats_swapped[1]].to_upper()), tr(Keys.hash_to_string[stats_swapped[0]].to_upper())]


func _find_min_max_stat_keys(player_index: int) -> Array:
	var min_stat_key = Keys.empty_hash
	var max_stat_key = Keys.empty_hash

	var stat_keys = Utils.get_primary_stat_keys()

	for stat_key in stat_keys:
		var current_stat = Utils.get_stat(stat_key, player_index)

		if current_stat <= 0:
			continue

		if min_stat_key == Keys.empty_hash or current_stat < Utils.get_stat(min_stat_key, player_index):
			min_stat_key = stat_key

		if max_stat_key == Keys.empty_hash or current_stat > Utils.get_stat(max_stat_key, player_index):
			max_stat_key = stat_key

	if min_stat_key == Keys.empty_hash:
		min_stat_key = Keys.stat_max_hp_hash

	if max_stat_key == Keys.empty_hash:
		max_stat_key = Keys.stat_max_hp_hash

	return [min_stat_key, max_stat_key]


func serialize() -> Dictionary:
	var serialized = .serialize()

	serialized.stats_swapped = stats_swapped
	serialized.has_been_applied = has_been_applied

	return serialized


func deserialize_and_merge(serialized: Dictionary) -> void:
	.deserialize_and_merge(serialized)

	stats_swapped = serialized.stats_swapped if "stats_swapped" in serialized else []

	for i in range(stats_swapped.size()):
		if stats_swapped[i] is float:
			stats_swapped[i] = int(stats_swapped[i])

		elif stats_swapped[i] is String:
			stats_swapped[i] = Keys.generate_hash(stats_swapped[i])

	if serialized.has("has_been_applied"):
		has_been_applied = serialized.has_been_applied
