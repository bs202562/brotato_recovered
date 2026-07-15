class_name WeaponStackEffect
extends NullEffect

@export var weapon_stacked_name: String
@export var weapon_stacked_id: String
@export var stat_displayed_name: String = "stat_damage"
@export var stat_name: String = "damage"
var weapon_stacked_id_hash = Keys.generate_hash(weapon_stacked_id)


static func get_id() -> String:
	return "weapon_stack"

func _generate_hashes() -> void :
	super._generate_hashes()
	weapon_stacked_id_hash = Keys.generate_hash(weapon_stacked_id)

func duplicate(subresources: = false) -> Resource:
	var duplication = super.duplicate(subresources)
	duplication.weapon_stacked_id_hash = weapon_stacked_id_hash
	return duplication

func get_args(player_index: int) -> Array:
	var nb_same_weapon = - 1
	for checked_weapon in RunData.get_player_weapons_ref(player_index):
		if checked_weapon.weapon_id == weapon_stacked_id:
			nb_same_weapon += 1

	return [str(value), tr(stat_displayed_name.to_upper()), tr(weapon_stacked_name.to_upper()), str(max(0, nb_same_weapon * value))]


func serialize() -> Dictionary:
	var serialized = super.serialize()

	serialized.weapon_stacked_name = weapon_stacked_name
	serialized.weapon_stacked_id = weapon_stacked_id
	serialized.stat_displayed_name = stat_displayed_name
	serialized.stat_name = stat_name

	return serialized


func deserialize_and_merge(serialized: Dictionary) -> void :
	super.deserialize_and_merge(serialized)

	weapon_stacked_name = serialized.weapon_stacked_name
	weapon_stacked_id = serialized.weapon_stacked_id
	weapon_stacked_id_hash = Keys.generate_hash(weapon_stacked_id)
	stat_displayed_name = serialized.stat_displayed_name
	stat_name = serialized.stat_name
