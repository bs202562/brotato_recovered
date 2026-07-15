class_name ItemPanelUI
extends PanelContainer

signal mouse_hovered_category
signal mouse_exited_category


var player_color_index: = - 1: set = _set_player_color_index
func _set_player_color_index(v: int) -> void :
	player_color_index = v
	_update_stylebox()

var selected: = false: set = _set_selected
func _set_selected(v: bool) -> void :
	selected = v
	if selected:
		_checkmark.show()
		_item_description.modulate.a = 0.5
	else:
		_checkmark.hide()
		_item_description.modulate.a = 1.0

var item_data: ItemParentData

@onready var _checkmark = $"Checkmark"
@onready var _item_description = $"%ItemDescription"
@onready var _global_container = $"%MarginContainer"
@onready var _random_icon_container: Control = $"%random_icon_container"
@onready var _frame: Panel = $"%frame"

func set_data(p_item_data: ItemParentData, player_index: int) -> void :
	_random_icon_container.visible = false
	_global_container.visible = true
	item_data = p_item_data
	_item_description.set_item(p_item_data, player_index)
	_update_stylebox()


func set_custom_data(name: String, icon: Resource) -> void :
	item_data = null
	_item_description.set_custom_data(name, icon)
	_update_stylebox()


func _on_ItemDescription_mouse_hovered_category() -> void :
	emit_signal("mouse_hovered_category")


func _on_ItemDescription_mouse_exited_category() -> void :
	emit_signal("mouse_exited_category")


func _update_stylebox() -> void :
	remove_theme_stylebox_override("panel")
	var stylebox = get_theme_stylebox("panel").duplicate()
	if item_data != null:
		ItemService.change_panel_stylebox_from_tier(stylebox, item_data.tier, false, $"%frame")
	if player_color_index >= 0:
		CoopService.change_stylebox_for_player(stylebox, player_color_index)
	add_theme_stylebox_override("panel", stylebox)


func _update_frame(stylebox: StyleBox) -> void :
	if stylebox == null:
		_frame.visible = false
	else:
		_frame.visible = true
		_frame.add_theme_stylebox_override("panel", stylebox)


func _show_random():
	_random_icon_container.visible = true
	_global_container.visible = false
