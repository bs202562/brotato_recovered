class_name ZoneData
extends Resource

@export var my_id = 0 # (int, 0, 9999)
@export var unlocked_by_default: bool = false
@export var name: String = ""
@export var icon: Resource = null
@export var width: int = 32
@export var height: int = 24
@export var waves_data: Array = [] # (Array, Resource)

@export var loot_alien_groups: Array = [] # (Array, Resource)
@export var groups_data_in_all_waves: Array = [] # (Array, Resource)
@export var horde_groups: Array = [] # (Array, Resource)
@export var endless_enemy_scenes: Array = [] # (Array, Resource)
@export var endless_nightmare_enemy_scenes: Array = [] # (Array, Resource)
@export var default_backgrounds = [] # (Array, Resource)
@export var fruit_sprite: Resource
@export var item_box_sprite: Resource
@export var legendary_box_sprite: Resource
@export var ui_background: Resource


func get_zone_consumable_sprite(consumable: ConsumableData) -> Texture2D:
	var sprite: Texture2D

	match consumable.my_id_hash:
		Keys.consumable_fruit_hash:
			sprite = fruit_sprite
		Keys.consumable_item_box_hash:
			sprite = item_box_sprite
		Keys.consumable_legendary_item_box_hash:
			sprite = legendary_box_sprite
		_:
			sprite = consumable.icon

	return sprite
