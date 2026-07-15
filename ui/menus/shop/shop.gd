
class_name Shop
extends BaseShop

@onready var _title = $"%Title"
@onready var _endless_button = $"%EndlessButton"
@onready var _go_button = $"%GoButton"
@onready var _stat_popup: StatPopup = $"%StatPopup"
@onready var _stats_container: StatsContainer
@onready var _block_background = $Content / BlockBackground

var focus_before_pause: Control


func _ready() -> void :
	super._ready() # 4.x 移植: Godot 3 自动调用父类虚函数，4.x 需显式调用
	_title.text = tr("MENU_SHOP") + " (" + Text.text("WAVE", [str(RunData.current_wave)]) + ")"

	_stats_container.update_player_stats(0)
	_popup_manager.connect_stats_container(_stats_container)

	_popup_manager.add_stat_popup(_stat_popup, 0)
	_popup_manager.connect_shop_items_container(_get_shop_items_container(0))

	_background.texture = ZoneService.get_zone_data(RunData.current_zone).ui_background

	_block_background.hide()

	_endless_button.visible = RunData.should_show_endless_button()
	if _endless_button.visible:
		_go_button.focus_neighbor_top = _endless_button.get_path()
		_stats_container.focus_neighbor_bottom = _endless_button.get_path()
		_stats_container.set_focus_neighbours()


func _input(event: InputEvent) -> void :
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		enable_shop_buttons_focus()
	if event.is_action_released("ui_cancel"):
		if _block_background.visible:
			_block_background.hide()
	super._input(event) # 4.x 移植: Godot 3 自动调用父类虚函数，4.x 需显式调用


func on_paused() -> void :
	focus_before_pause = get_viewport().gui_get_focus_owner()
	super.on_paused()


func on_unpaused() -> void :
	if focus_before_pause:
		focus_before_pause.grab_focus()
	else:
		_go_button.grab_focus()

	super.on_unpaused()


func disable_shop_buttons_focus() -> void :
	_get_shop_items_container(0).disable_shop_buttons_focus()


func enable_shop_buttons_focus() -> void :
	_get_shop_items_container(0).enable_shop_buttons_focus()


func disable_shop_lock_buttons_focus() -> void :
	_get_shop_items_container(0).disable_shop_lock_buttons_focus()


func enable_shop_lock_buttons_focus() -> void :
	_get_shop_items_container(0).enable_shop_lock_buttons_focus()


func _on_EndlessButton_pressed() -> void :
	RunData.is_endless_run = true
	_on_GoButton_pressed(0)


func _on_element_focused(element: InventoryElement, player_index: int) -> void :
	super._on_element_focused(element, player_index)

	
	disable_shop_buttons_focus()
	disable_shop_lock_buttons_focus()

	
	_stats_container.disable_focus()


func _on_element_unfocused(element: InventoryElement, player_index: int) -> void :
	super._on_element_unfocused(element, player_index)

	
	enable_shop_buttons_focus()


func _on_element_pressed(element: InventoryElement, player_index: int, popup_focused: bool) -> void :
	
	if _focused_shop_item[player_index] != null:
		_focused_shop_item[player_index]._can_be_selected(false)

	super._on_element_pressed(element, player_index, popup_focused)
	if popup_focused:
		_block_background.show()
	else:
		_on_player_focus_lost(0)


func _on_item_combine_button_pressed(weapon_data: WeaponData, player_index: int) -> void :
	_block_background.hide()
	super._on_item_combine_button_pressed(weapon_data, player_index)

	if _focused_shop_item[player_index] != null:
		_focused_shop_item[player_index]._can_be_selected()


func _on_item_discard_button_pressed(weapon_data: WeaponData, player_index: int) -> void :
	_block_background.hide()
	super._on_item_discard_button_pressed(weapon_data, player_index)

	if _focused_shop_item[player_index] != null:
		_focused_shop_item[player_index]._can_be_selected()


func _on_item_cancel_button_pressed(item_data: ItemParentData, player_index: int) -> void :
	_block_background.hide()
	super._on_item_cancel_button_pressed(item_data, player_index)

	if _focused_shop_item[player_index] != null:
		_focused_shop_item[player_index]._can_be_selected()


func on_shop_item_focused(_shop_item: ShopItem) -> void :
	# 4.x 移植: 原 .on_shop_item_focused() 调用的父类方法在 BaseShop 中不存在(3.x 遗留死代码)，移除
	_stats_container.disable_focus()



func _find_nodes() -> void :
	if _stats_container != null:
		return
	_stats_container = get_node("%StatsContainer") as StatsContainer


func _update_stats(_player_index: = - 1) -> void :
	_stats_container.update_player_stats(0)


func _get_shop_items_container(_player_index: int) -> ShopItemsContainer:
	return get_node("%ShopItemsContainer") as ShopItemsContainer


func _get_gear_container(_player_index: int) -> PlayerGearContainer:
	return get_node("%GearContainer") as PlayerGearContainer


func _get_gold_label(_player_index: int) -> Control:
	return get_node("%GoldLabel") as Control


func _get_reroll_button(_player_index: int) -> Control:
	return get_node("%RerollButton") as Control


func _get_go_button(_player_index: int) -> Control:
	return get_node("%GoButton") as Control


func _get_item_popup(_player_index: int) -> ItemPopup:
	return get_node("%ItemPopup") as ItemPopup


func _get_elite_info_panel(_player_index: int) -> EliteInfoPanel:
	return get_node("%EliteInfoPanel") as EliteInfoPanel


func _get_elite_container(_player_index: int) -> Container:
	return get_node("%EliteContainer") as Container
