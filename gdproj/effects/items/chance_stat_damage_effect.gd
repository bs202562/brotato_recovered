class_name ChanceStatDamageEffect
extends Effect

export(int) var chance := 3
export(String) var tracking_text
var tracking_key: int = Keys.empty_hash


static func get_id() -> String:
	return "chance_stat_damage"


func _generate_hashes() -> void:
	._generate_hashes()
	tracking_key = Keys.generate_hash(tracking_text)


func apply(player_index: int) -> void:



	RunData.get_player_effects(player_index)[custom_key_hash].push_back([key_hash, value, chance, tracking_key])


func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value, chance, tracking_key])


func get_args(player_index: int) -> Array:

	var dmg = value
	var scaling_text = ""

	if key != "":
		assert(key_hash != Keys.empty_hash)

		var dmg_from_stat := ((value / 100.0) * Utils.get_stat(key_hash, player_index)) as int
		dmg = WeaponService.apply_damage_bonus(dmg_from_stat, player_index)
		var show_plus_prefix := false
		scaling_text = Utils.get_scaling_stat_icon_text(key_hash, value / 100.0, show_plus_prefix)

	return [str(chance), str(dmg), scaling_text]


func serialize() -> Dictionary:
	var serialized = .serialize()

	serialized.chance = chance
	serialized.tracking_text = tracking_text

	return serialized


func deserialize_and_merge(serialized: Dictionary) -> void:
	.deserialize_and_merge(serialized)

	chance = serialized.chance as int
	tracking_text = serialized.tracking_text
	tracking_key = Keys.generate_hash(tracking_text)


func duplicate(subresources := false) -> Resource:
	var duplication = .duplicate(subresources)
	duplication.tracking_key = tracking_key
	return duplication
