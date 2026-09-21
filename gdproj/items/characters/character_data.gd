class_name CharacterData
extends ItemData

export (Array, String) var wanted_tags
export (Array, String) var banned_item_groups
export (Array, String) var banned_items
export (Array, String) var banned_upgrades
export (Array, Resource) var starting_weapons
export (Array, Resource) var starting_items


func get_category() -> int:
	return Category.CHARACTER
