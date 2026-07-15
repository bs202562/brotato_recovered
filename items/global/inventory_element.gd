class_name InventoryElement
extends Button

signal element_hovered(element)
signal element_unhovered(element)
signal element_focused(element)
signal element_unfocused(element)
signal element_pressed(element)

export (Resource) var sound_on_focus
export (Resource) var sound_on_pressed

var item: Resource
var is_random: = false
var is_special: = false
var current_number: = 0
var display_banned: float = 0
var background_transparency: = float(0.25)
var background_modulate: = Color(1, 1, 1, 0)
var player_index: = 0

onready var _number_label = $Label
onready var _icon = $"%Icon"
onready var _curse = $"%Curse"
onready var _baned = $"%Baned"
onready var _frame_panel: Panel = $frame


func set_element(item_data: Resource) -> void :
	item = item_data
	_icon.texture = item_data.get_icon()
	update_background_color()
	update_banned_item()
	current_number = 1

	if item_data is ItemParentData and item_data.is_cursed:
		_curse.visible = true
	else:
		_curse.visible = false


func add_to_number(value: int = 1, forcenumber: bool = false) -> void :
	current_number += value
	_number_label.text = "x" + str(current_number)

	if current_number > 1 or forcenumber:
		_number_label.show()


func remove_from_number(value: int = 1) -> void :
	current_number -= value
	_number_label.text = "x" + str(current_number)

	if current_number <= 1:
		_number_label.hide()


func set_icon(p_icon: Resource) -> void :
	_icon.texture = p_icon

	if item == null:
		_curse.visible = false


func set_number(p_number: int) -> void :
	_number_label.text = str(p_number)


func set_font(font: Resource) -> void :
	_number_label.add_font_override("font", font)


func get_inventory_icon() -> Texture:
	return _icon.texture


func set_element_size(p_size: Vector2) -> void :
	rect_min_size = p_size
	rect_size = p_size


func silouhette_if_hidden_in_codex() -> void :
	if _icon != null:
		_icon.modulate = Color(0, 0, 0, 1) if item._is_silhouette_in_codex() else Color(1, 1, 1, 1)


func update_banned_item() -> void :
	if display_banned <= 0:
		_baned.visible = false
		return

	var show_banned: = false
	if RunData.players_data[player_index].banned_items.has(item.my_id_hash):
		show_banned = true
	elif item is WeaponData and RunData.players_data[player_index].banned_items.has(item.weapon_id_hash):
		show_banned = true

	if show_banned:
		_baned.modulate = Color(ProgressData.settings.color_negative)
		_baned.modulate.a = display_banned
		_baned.visible = true
	else:
		_baned.visible = false


func update_background_color(p_color: int = - 1) -> void :
	if item == null:
		return
	var stylebox_color = get_stylebox("normal").duplicate()
	if item is ItemEntity:
		ItemService.change_inventory_element_stylebox_from_entity_type(stylebox_color, item, 0.25)
	else:
		ItemService.change_inventory_element_stylebox_from_tier(stylebox_color, p_color if p_color != - 1 else item.tier, 0.25, _frame_panel)
	stylebox_color.bg_color = lerp(stylebox_color.bg_color, Color(background_modulate.r, background_modulate.g, background_modulate.b), background_modulate.a)
	stylebox_color.bg_color.a = background_transparency
	add_stylebox_override("normal", stylebox_color)


func _on_InventoryElement_mouse_entered() -> void :
	SoundManager.play(sound_on_focus, - 5, 0.2)
	emit_signal("element_hovered", self)


func _on_InventoryElement_mouse_exited() -> void :
	emit_signal("element_unhovered", self)


func _on_InventoryElement_focus_entered() -> void :
	SoundManager.play(sound_on_focus, - 5, 0.2)
	emit_signal("element_focused", self)


func _on_InventoryElement_focus_exited() -> void :
	emit_signal("element_unfocused", self)


func _on_InventoryElement_pressed() -> void :
	SoundManager.play(sound_on_pressed, 0, 0.2)
	emit_signal("element_pressed", self)
