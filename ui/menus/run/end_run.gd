extends BaseEndRun

@onready var _weapons_container = $"%WeaponsContainer"
@onready var _items_container = $"%ItemsContainer"
@onready var _progress_container = $"%ProgressContainer"
@onready var _stats_container = $"%StatsContainer"
@onready var _background = $"%Background"
@onready var _stat_popup = $StatPopup
@onready var _item_popup = $ItemPopup
@onready var _unlockall_icon: TextureRect = $"%unlockall_icon"


func _ready() -> void :
	super._ready() # 4.x 移植: Godot 3 自动调用父类虚函数，4.x 需显式调用
	TempStats.reset()
	LinkedStats.reset()

	_stats_container.disable_focus()
	_stats_container.update_player_stats(0)

	var weapons = RunData.get_player_weapons(0)
	var items = RunData.get_player_items(0)
	_weapons_container.set_data("WEAPONS", Category.WEAPON, weapons)
	_items_container.set_data("ITEMS", Category.ITEM, items, true, true)

	var rewards = []

	if RunData.difficulty_unlocked != - 1:
		var difficulty_data = null
		for difficulty in ItemService.difficulties:
			if difficulty.value == RunData.difficulty_unlocked:
				difficulty_data = difficulty
				break
		rewards.push_back(difficulty_data)

	for chal in RunData.challenges_completed_this_run:
		rewards.push_back(chal.reward)

	_progress_container.set_data("MENU_PROGRESS", Category.CHALLENGE, rewards)

	_popup_manager.add_item_popup(_item_popup, 0)
	_popup_manager.connect_inventory_container(_weapons_container)
	_popup_manager.connect_inventory_container(_items_container)
	_popup_manager.connect_inventory_container(_progress_container)

	_popup_manager.add_stat_popup(_stat_popup, 0)
	_popup_manager.connect_stats_container(_stats_container)

	_background.texture = ZoneService.get_zone_data(RunData.current_zone).ui_background

	if RunData.challenges_completed_this_run.size() > 0:
		_progress_container.focus_element_index(0)
	else:
		_new_run_button.grab_focus()

	_unlockall_icon.visible = ProgressData.is_unlock_all_save()

	await get_tree().process_frame
	_items_container._elements.emit_signal("need_to_sort_inventory")
	_weapons_container._elements.emit_signal("need_to_sort_inventory")


func _on_PopupManager_element_pressed(_element: InventoryElement, _player_index: int, _popup_focused: bool):
	_new_run_button.grab_focus()
