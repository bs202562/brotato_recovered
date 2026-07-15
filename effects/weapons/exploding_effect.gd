class_name ExplodingEffect
extends NullEffect

@export var chance: = 1.0 # (float, 0.0, 1.0, 0.01)
@export var explosion_scene: PackedScene
@export var scale := 1.0
@export var base_smoke_amount := 40
@export var sound_db_mod := - 10

var explosion_pool_id: int = Keys.empty_hash

static func get_id() -> String:
	return "weapon_exploding"


func _ready() -> void :
	if explosion_scene != null:
		explosion_pool_id = explosion_scene.get_instance_id()


func get_args(_player_index: int) -> Array:
	return [str(round(chance * 100.0))]


func serialize() -> Dictionary:
	var serialized = super.serialize()

	serialized.chance = chance

	if explosion_scene != null:
		serialized.explosion_scene = explosion_scene.resource_path

	serialized.scale = scale
	serialized.base_smoke_amount = base_smoke_amount
	serialized.sound_db_mod = sound_db_mod

	return serialized


func deserialize_and_merge(serialized: Dictionary) -> void :
	super.deserialize_and_merge(serialized)

	chance = serialized.chance
	if serialized.has("explosion_scene"):
		explosion_scene = load(serialized.explosion_scene)
		explosion_pool_id = explosion_scene.get_instance_id()
	scale = serialized.scale
	base_smoke_amount = serialized.base_smoke_amount as int
	sound_db_mod = serialized.sound_db_mod as int
