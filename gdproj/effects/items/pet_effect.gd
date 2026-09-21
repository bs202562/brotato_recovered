class_name PetEffect
extends Effect

export(PackedScene) var scene = null
export(bool) var is_structure = false
var is_cursed = false

static func get_id() -> String:
	return "pet"

func apply(player_index: int) -> void:
	if scene != null:
		RunData.get_player_effect(Keys.stat_pets_hash, player_index).push_back(self)

func unapply(player_index: int) -> void:
	if scene != null:
		RunData.get_player_effect(Keys.stat_pets_hash, player_index).erase(self)

func serialize() -> Dictionary:
	var serialized = .serialize()
	serialized.scene = scene.resource_path if scene else null
	serialized.is_structure = is_structure
	serialized.is_cursed = is_cursed
	return serialized

func deserialize_and_merge(serialized: Dictionary) -> void:
	.deserialize_and_merge(serialized)

	if serialized.has("is_structure"):
		is_structure = serialized.is_structure

	if serialized.has("is_cursed"):
		is_cursed = serialized.is_cursed

	if serialized.scene != null:
		var pet_scene_path = serialized.scene as String
		if pet_scene_path != "":
			scene = ResourceLoader.load(pet_scene_path) as PackedScene
