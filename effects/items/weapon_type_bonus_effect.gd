class_name WeaponTypeBonusEffect
extends Effect

enum Type { MELEE, RANGED }

@export var weapon_type: Type
@export var stat_displayed_name: String
@export var stat_name: String
var stat_hash: int = Keys.empty_hash


static func get_id() -> String:
	return "weapon_type_bonus"


func _generate_hashes() -> void:
	super._generate_hashes()
	stat_hash = Keys.generate_hash(stat_name)


func apply(player_index: int) -> void:
	assert(stat_hash != Keys.empty_hash)
	RunData.get_player_effects(player_index)[Keys.weapon_type_bonus_hash].push_back([weapon_type, stat_hash, value])


func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[Keys.weapon_type_bonus_hash].erase([weapon_type, stat_hash, value])


func get_args(_player_index: int) -> Array:
	return [str(value), tr(stat_displayed_name.to_upper())]


func serialize() -> Dictionary:
	var serialized = super.serialize()

	serialized.weapon_type = weapon_type
	serialized.stat_displayed_name = stat_displayed_name
	serialized.stat_name = stat_name

	return serialized


func deserialize_and_merge(serialized: Dictionary) -> void:
	super.deserialize_and_merge(serialized)

	weapon_type = serialized.weapon_type if "weapon_type" in serialized else Type.MELEE
	stat_displayed_name = serialized.stat_displayed_name if "stat_displayed_name" in serialized else ""
	stat_name = serialized.stat_name if "stat_name" in serialized else ""
	stat_hash = Keys.generate_hash(stat_name)


func duplicate(subresources := false) -> Resource:
	var duplication = super.duplicate(subresources)

	if stat_hash == Keys.empty_hash and stat_name != "":
		stat_hash = Keys.generate_hash(stat_name)

	duplication.stat_hash = stat_hash

	return duplication
