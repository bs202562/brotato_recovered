class_name CoopItemPopup
extends ItemPopup

signal popup_toggled(hide_popup, player_index)

@onready var _replaceable_box_container: BoxContainer = $"%ReplaceableVBoxContainer"
@onready var _coop_inventory_hint = $"%CoopInventoryHint"
@onready var _coop_lock_hint = $"%CoopLockHint"
@onready var _coop_unlock_hint = $"%CoopUnlockHint"
@onready var _coop_steal_hint = $"%CoopStealHint"
@onready var _coop_ban_hint = $"%CoopBanHint"

var shop_item: ShopItem

var _hide_popup: = false


var _active: = false

func _set_player_index(value: int) -> void :
	super._set_player_index(value)
	for hint in [_coop_lock_hint, _coop_unlock_hint, _coop_inventory_hint, _coop_ban_hint]:
		hint.player_index = value


func _ready() -> void :
	super._ready() # 4.x 移植: Godot 3 自动调用父类虚函数，4.x 需显式调用
	if RunData.get_player_count() == 2:
		var h_box_container: = HBoxContainer.new()
		var old_container: = _replaceable_box_container
		_replaceable_box_container.replace_by(h_box_container)
		old_container.queue_free()
		_replaceable_box_container = h_box_container
	set_process_input(false)


func _input(event: InputEvent) -> void :
	_input_self(event)
	super._input(event) # 4.x 移植: Godot 3 会自动调用父类，且子类的 return 不影响父类执行


func _input_self(event: InputEvent) -> void :
	if not _active or _focused:
		return
	if Utils.is_player_info_pressed(event, player_index):
		_hide_popup = not _hide_popup
		visible = not visible
		emit_signal("popup_toggled", _hide_popup, player_index)


func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if _hide_popup == true:
			set_process_input(true)
		else:
			set_process_input(is_visible_in_tree())
	super._notification(what) # 4.x 移植: Godot 3 自动调用父类虚函数，4.x 需显式调用


func hide(player_index: = - 1) -> void :
	super.hide(player_index)
	_active = false


func show() -> void :
	super.show()
	_active = true
	if _hide_popup:
		visible = false


func focus() -> void :
	super.focus()
	visible = true


func show_shop_hints(p_shop_item: ShopItem) -> void :
	if item_steals > 0:
		_coop_steal_hint.visible = true

		var steal_spawn_elite_effect = RunData.get_player_effect(Keys.item_steals_spawns_random_elite_hash, player_index)
		var steal_chance = ItemService.get_chance_getting_caught(p_shop_item, RunData.current_wave, steal_spawn_elite_effect / 100.0)

		var displayed_steal_chance = steal_chance * 100.0

		if displayed_steal_chance < 1.0:
			displayed_steal_chance = snapped(displayed_steal_chance, 0.1)
		else:
			displayed_steal_chance = snapped(displayed_steal_chance, 1.0)

		_coop_steal_hint.set_steal_percentage(displayed_steal_chance)

	else:
		_coop_steal_hint.visible = false

	if RunData.get_player_effect_bool(Keys.disable_item_locking_hash, player_index) or not p_shop_item.item_data.is_lockable:
		_coop_unlock_hint.visible = false
		_coop_lock_hint.visible = false
	else:
		_coop_unlock_hint.visible = p_shop_item.locked
		_coop_lock_hint.visible = not p_shop_item.locked

	if p_shop_item.item_data is WeaponData:
		_coop_ban_hint.visible = false
	else:
		_coop_ban_hint.visible = RunData.players_data[player_index].remaining_ban_token > 0 and ChallengeService.is_challenge_completed(ChallengeService.chal_banned_items_hash) and RunData.is_ban_active_in_current_run()
	_coop_ban_hint.update_text()


func show_inventory_hint(item_data: ItemParentData) -> void :
	if will_show_buttons_when_focused(item_data):
		_coop_inventory_hint.show()


func hide_hints() -> void :
	_coop_inventory_hint.hide()
	_coop_unlock_hint.hide()
	_coop_lock_hint.hide()
	_coop_steal_hint.hide()
	_coop_ban_hint.hide()

