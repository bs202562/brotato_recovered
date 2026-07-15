class_name IngameMainMenu
extends Control


signal options_button_pressed
signal codex_button_pressed
signal resume_button_pressed
signal quit_button_pressed
signal restart_button_pressed
signal end_run_button_pressed



var player_index: = 0
func _set_player_index(p_player_index: int) -> void :
	player_index = p_player_index

	_coop_player_selector.index = player_index
	_item_popup.player_index = player_index
	_stats_container.update_player_stats(player_index)

	var weapons = RunData.get_player_weapons(player_index)
	_weapons_container.set_data(_get_weapons_label_text(player_index), Category.WEAPON, weapons)

	_switch_to_ban_items(false)

	if not _button_banned_items.is_connected("toggled", self, "_switch_to_ban_items"):
		_button_banned_items.connect("toggled", self, "_switch_to_ban_items")

	if RunData.get_player_banned_items(player_index).size() <= 0:
		_button_banned_items.visible = false
	else:
		_button_banned_items.visible = true


var _popup_manager_initialized: = false

onready var _resume_button = $"%ResumeButton"
onready var _buttons_array = [$"%ResumeButton", $"%CodexButton", $"%RestartButton", $"%EndRunButton", $"%OptionsButton", $"%QuitButton"]
onready var _weapons_container = $"%WeaponsContainer"
onready var _items_container = $"%ItemsContainer"
onready var _button_banned_items: Button = $"%button_banned_items"
onready var _stats_container = $"%StatsContainer"
onready var _popup_manager = $"%PopupManager"
onready var _item_popup = $ItemPopup
onready var _stat_popup = $StatPopup
onready var _timeline: UITimeline = $"%ui_timeline" as UITimeline
onready var _difficulty_label = $"%DifficultyLabel"
onready var _coop_player_selector = $"%CoopPlayerSelector"


func init(p_player_index: = 0) -> void :
	_set_player_index(p_player_index)
	_weapons_container.player_index = player_index
	_items_container.player_index = player_index
	_coop_player_selector.visible = RunData.is_coop_run
	if not is_focus_already_own_by_buttons():
		_resume_button.grab_focus()

	if not _popup_manager_initialized:
		_popup_manager_initialized = true
		_popup_manager.connect("element_focused", self, "_on_inventory_element_focused")
		_popup_manager.connect_inventory_container(_weapons_container)
		_popup_manager.connect_inventory_container(_items_container)
		_popup_manager.connect_stats_container(_stats_container)
		for popup_player_index in RunData.get_player_count():
			
			_popup_manager.add_item_popup(_item_popup, popup_player_index)
			_popup_manager.add_stat_popup(_stat_popup, popup_player_index)

	_timeline._set_timeline()

	_difficulty_label.text = "%s%s%s%s" % [
		Text.text(ItemService.get_element(ItemService.difficulties, Keys.empty_hash, RunData.current_difficulty).name, [str(RunData.current_difficulty)]), 
		" - " + tr("ENDLESS") if RunData.is_endless_run else "", 
		Utils.get_enemy_scaling_text(
			RunData.current_run_accessibility_settings.health, 
			RunData.current_run_accessibility_settings.damage, 
			RunData.current_run_accessibility_settings.speed, 
			RunData.retries, 
			RunData.is_coop_run, 
			0 if not RunData.is_ban_active_in_current_run() else RunData.get_used_ban_count(), 
			RunData.constant_projectile if RunData.current_difficulty > 5 else 1
		), 
		" - " + Text.text("WAVE", [str(RunData.current_wave)])
	]
	_update_color()


func _update_color() -> void :
	_button_banned_items.get_node("icon").modulate = Color(ProgressData.settings.color_negative)


func is_focus_already_own_by_buttons() -> bool:
	var focus_owner = get_focus_owner()
	if focus_owner == null:
		return false
	else:
		for button in _buttons_array:
			if focus_owner == button:
				return true
	return false

func _on_ResumeButton_pressed() -> void :
	emit_signal("resume_button_pressed")


func _on_CodexButton_pressed() -> void :
	emit_signal("codex_button_pressed")


func _on_OptionsButton_pressed() -> void :
	emit_signal("options_button_pressed")


func _on_QuitButton_pressed() -> void :
	emit_signal("quit_button_pressed")


func _on_RestartButton_pressed() -> void :
	emit_signal("restart_button_pressed")


func _on_CoopPlayerSelector_index_changed(p_player_index: int):
	_set_player_index(p_player_index)


func _on_inventory_element_focused(_element, _player_index) -> void :
	
	_stats_container.disable_focus()


func _get_weapons_label_text(p_player_index: int) -> String:
	var weapons = RunData.get_player_weapons(p_player_index)
	return tr("WEAPONS") + " (" + str(weapons.size()) + "/" + str(RunData.get_player_effect(Keys.weapon_slot_hash, p_player_index)) + ")"


func _switch_to_ban_items(toggled: bool):
	_items_container._elements.display_banned = 0.5 if toggled else 0.0
	if not toggled:
		var items = RunData.get_player_items(player_index)
		_items_container.set_data("ITEMS", Category.ITEM, items, true, true)
	else:
		var items = RunData.get_player_banned_items(player_index)
		_items_container.set_data("ITEMS", Category.ITEM, items, true, true)


func _on_EndRunButton_pressed():
	emit_signal("end_run_button_pressed")

