class_name ClassBonusEffect
extends Effect

@export var set_id: String = ""
@export var stat_displayed_name: String = "stat_damage"
@export var stat_name: String = "damage"
var stat_hash: int = Keys.empty_hash
var set_id_hash: int = Keys.empty_hash

func duplicate(subresources := false) -> Resource:
	var duplication = super.duplicate(subresources)
	duplication.stat_hash = stat_hash
	duplication.set_id_hash = set_id_hash
	return duplication

func _generate_hashes() -> void:
	super._generate_hashes()
	stat_hash = Keys.generate_hash(stat_name)
	set_id_hash = Keys.generate_hash(set_id)


static func get_id() -> String:
	return "class_bonus"


func apply(player_index: int) -> void:
	var effects = RunData.get_player_effects(player_index)
	effects[Keys.weapon_class_bonus_hash].push_back([set_id_hash, stat_hash, value])


func unapply(player_index: int) -> void:
	var effects = RunData.get_player_effects(player_index)
	effects[Keys.weapon_class_bonus_hash].erase([set_id_hash, stat_hash, value])


func get_args(_player_index: int) -> Array:
	var set = ItemService.get_set(set_id_hash)
	return [str(value), tr(stat_displayed_name.to_upper()), tr(set.name)]


func serialize() -> Dictionary:
	var serialized = super.serialize()

	serialized.set_id = set_id
	serialized.stat_displayed_name = stat_displayed_name
	serialized.stat_name = stat_name

	return serialized


func deserialize_and_merge(serialized: Dictionary) -> void:
	super.deserialize_and_merge(serialized)

	set_id = serialized.set_id if "set_id" in serialized else ""
	set_id_hash = Keys.generate_hash(set_id)
	stat_displayed_name = serialized.stat_displayed_name if "stat_displayed_name" in serialized else "stat_damage"
	stat_name = serialized.stat_name if "stat_name" in serialized else "damage"
	stat_hash = Keys.generate_hash(stat_name)
