class_name StatGainsModificationEffect
extends Effect

@export var stat_displayed: String = ""
@export var stats_modified: Array = [] # (Array, String)


static func get_id() -> String:
	return "stat_gains_modifications"


func apply(player_index: int) -> void:
	var effects = RunData.get_player_effects(player_index)
	for stat in stats_modified:
		assert(stat is String and not stat.is_valid_int())
		effects[Keys.generate_hash("gain_" + stat)] += value


func unapply(player_index: int) -> void:
	var effects = RunData.get_player_effects(player_index)
	for stat in stats_modified:
		assert(stat is String and not stat.is_valid_int())
		effects[Keys.generate_hash("gain_" + stat)] -= value


func get_args(_player_index: int) -> Array:
	return [tr(stat_displayed.to_upper()), str(abs(value))]


func serialize() -> Dictionary:
	var serialized = super.serialize()

	serialized.stat_displayed = stat_displayed
	serialized.stats_modified = stats_modified

	return serialized


func deserialize_and_merge(serialized: Dictionary) -> void:
	super.deserialize_and_merge(serialized)

	stat_displayed = serialized.stat_displayed
	stats_modified = serialized.stats_modified
