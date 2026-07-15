class_name CharacterData
extends ItemData

@export var wanted_tags: Array = [] # (Array, String)
@export var banned_item_groups: Array = [] # (Array, String)
@export var banned_items: Array = [] # (Array, String)
@export var banned_upgrades: Array = [] # (Array, String)
@export var starting_weapons: Array = [] # (Array, Resource)
@export var starting_items: Array = [] # (Array, Resource)


func get_category() -> int:
	return Category.CHARACTER
