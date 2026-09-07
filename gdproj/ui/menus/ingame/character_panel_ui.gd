class_name CharacterPanelUI
extends ItemPanelUI

const SCROLL_SPEED: = 600.0
const MenuCharacterPreview = preload("res://combat3d/menu_character_preview.gd")
var _preview_3d

onready var _characterName: Label = $"%CharacterName"
onready var _inventory: Inventory = $"%Inventory"
onready var _leftPanel: VBoxContainer = $"%left_panel"
onready var _rightPanel: PanelContainer = $"%right_panel"
onready var _scroll_container: ScrollContainer = $"%ScrollContainer"
onready var _scroll_name: ScrollContainer = $"%ScrollContainer_name"
onready var _scroll_box_inventory: ScrollContainer = $"%ScrollBoxInventory"
onready var _left_panel_color: PanelContainer = $"%left_panel_color"
onready var _character_infos_container: GridContainer = $"%character_infos_container"
onready var _animation_player: AnimationPlayer = $"%AnimationPlayer"
onready var _chara_visual: Control = $"%CharacterVisual"
onready var _tilemap: TileMap = $"%TileMap"
onready var _characterAnimation: Node2D = $"%CharacterAnimation"
onready var _inventory_container: Control = $"%inventory_container"
onready var _item_popup = $"%ItemPopup"

export (int) var player_index: = 0
var all_sprites_appearance: Array


func _set_player_color_index(v: int) -> void :
	player_color_index = v
	_item_popup.player_index = player_index

func _process(delta: float) -> void :
	_scroll_container.scroll_vertical += int(Utils.get_player_rjoy_vector(player_index).y * SCROLL_SPEED * delta)
	_scroll_name.scroll_horizontal += int(Utils.get_player_rjoy_vector(player_index).x * SCROLL_SPEED * delta)


func _ready():
	_animation_player.stop()
	_characterAnimation.hide()
	_preview_3d = MenuCharacterPreview.new()
	_preview_3d.name = "CharacterPreview3D"
	_chara_visual.add_child(_preview_3d)
	_update_bg()


func on_show_shop_item_popup(shop_item: ShopItem) -> void :
	_item_popup.shop_item = shop_item
	_item_popup.set_synergies_visible(true)
	_item_popup.show_shop_hints(shop_item)


func on_hide_shop_item_popup(_shop_item: ShopItem) -> void :
	_item_popup.shop_item = null
	_item_popup.set_synergies_visible(false)
	_item_popup.hide(player_index)


func on_show_inventory_popup(element: InventoryElement) -> void :
	_item_popup.set_synergies_visible(false)
	
	_item_popup.show_inventory_hint(element.item)


func on_hide_inventory_popup(_element: InventoryElement = null) -> void :
	_item_popup.hide(player_index)


func on_show_focused_inventory_popup() -> void :
	_item_popup.set_synergies_visible(true)
	_item_popup.hide(player_index)


func _update_bg():
	# The isolated 3D portrait replaces the old tiled paper-doll backdrop.
	_tilemap.hide()


func apply_objects_display(all_objects: Array, character: ItemParentData) -> void :
	if character != null:
		_preview_3d.show_character(character.my_id)
	if character != null:
		all_objects.append(character)
	

	var weapons: Array

	var items: Array
	for object in all_objects:
		if object is WeaponData:
			weapons.append(object)
		elif object is ItemData:
			items.append(object)
	apply_items_appearance(items)


func apply_items_appearance(all_items: Array) -> void :
	for sprite in all_sprites_appearance:
		sprite.queue_free()
	all_sprites_appearance = []
	# Equipment stays in the inventory/details UI; old 2D cosmetic sprites are
	# no longer layered over the identity supplied to the 3D visual factory.
	_characterAnimation.hide()

	


func _small(small):
	if small:
		_leftPanel.rect_min_size.x = 200
		_rightPanel.rect_min_size.x = 350
		_leftPanel.size_flags_vertical = Control.SIZE_FILL
		_character_infos_container.columns = 1
		_chara_visual.rect_scale = Vector2(0.9, 0.9)
		_characterAnimation.position.y = - 17.6
		_tilemap.visible = false
	else:
		_leftPanel.rect_min_size.x = 300
		_rightPanel.rect_min_size.x = 450
		_leftPanel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_character_infos_container.columns = 2
		_chara_visual.rect_scale = Vector2(1.25, 1.25)
		_characterName.modulate = Color(1, 1, 1)
		_left_panel_color.self_modulate.a = 0
		_characterAnimation.position.y = - 46.8
		_tilemap.visible = false




func set_data(p_item_data: ItemParentData, _player_index: int) -> void :
	on_hide_inventory_popup()
	_random_icon_container.visible = false
	_global_container.visible = true
	_chara_visual.visible = true
	_rightPanel.visible = true
	
	if RunData.is_coop_run:
		_characterName.modulate = CoopService.player_colors[player_index]
		_left_panel_color.self_modulate = CoopService.player_colors[player_index]
		_left_panel_color.self_modulate.v = 0.5
		_left_panel_color.self_modulate.a = 0.35
		_inventory_container.self_modulate = Color(1, 1, 1, 0)
	else:
		_characterName.modulate = Color(1, 1, 1)
		_inventory_container.self_modulate = Color(1, 1, 1, 1)
		_left_panel_color.self_modulate.a = 0

	item_data = p_item_data
	_item_description.set_item(p_item_data, player_index)

	_characterName.text = item_data.name

	
	var list_of_items: Array = []
	for effect in item_data.effects:
		match effect.custom_key_hash:
			Keys.starting_weapon_hash:
				var item = ItemService.get_element(ItemService.weapons, effect.key_hash)
				list_of_items.append(item)
			Keys.starting_item_hash:
				var item = ItemService.get_element(ItemService.items, effect.key_hash)
				list_of_items.append(item)
			Keys.cursed_starting_item_hash:
				var item = ItemService.get_element(ItemService.items, effect.key_hash)
				list_of_items.append(item)
			Keys.cursed_starting_weapon_hash:
				var item = ItemService.get_element(ItemService.weapons, effect.key_hash)
				list_of_items.append(item)

	_scroll_box_inventory.rect_min_size.x = list_of_items.size() * _scroll_box_inventory.rect_min_size.y
	_inventory.set_elements(list_of_items, false, true)
	apply_objects_display(list_of_items, p_item_data)
	_update_stylebox()





func set_custom_data(name: String, icon: Resource) -> void :
	item_data = null
	_item_description.set_custom_data(name, icon)
	_update_frame(null)
	_inventory.clear_elements()


func _show_random():
	._show_random()
	_chara_visual.visible = false
	_rightPanel.visible = false
	_characterName.text = Text.text("RANDOM")
	_inventory_container.self_modulate = Color(1, 1, 1, 0)
