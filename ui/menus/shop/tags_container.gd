class_name TagsContainer
extends VBoxContainer

const DIST = 5

var tag_panels: Array = []


func _ready() -> void :
	tag_panels = get_children()


func set_tags_text(item_data: ItemParentData, player_index: int) -> void :
	size = Vector2.ZERO

	var was_visible = visible
	if was_visible:
		hide()

	for panel in tag_panels:
		panel.hide()

	if item_data is ItemData and not item_data is CharacterData:
		var i = 0

		if item_data.is_pet_item():
			if tag_panels[i].set_data("pet"):
				i += 1
		if item_data.is_structure_item():
			if tag_panels[i].set_data("structure"):
				i += 1

	if was_visible:
		
		show()


func set_pos_from(elt: Control) -> void :
	global_position.x = elt.global_position.x + elt.size.x + DIST
	global_position.y = elt.global_position.y
