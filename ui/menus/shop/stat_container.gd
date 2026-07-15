class_name StatContainer
extends PanelContainer

signal focused(button, title, value, player_index)
signal unfocused(player_index)
signal hovered(button, title, value, player_index)
signal unhovered(player_index)

@export var key: String
@onready var key_hash: int = Keys.generate_hash(key.to_lower())

@onready var _icon = $HBoxContainer / Icon
@onready var _label = $HBoxContainer / Label
@onready var _value = $HBoxContainer / Value

var color_override: Color = Color.BLACK

func enable_focus() -> void :
	focus_mode = FOCUS_ALL


func disable_focus() -> void :
	focus_mode = FOCUS_NONE


func init_label_focus() -> void :
	_label.focus_mode = FOCUS_NONE
	_label.mouse_filter = MOUSE_FILTER_PASS


func update_player_stat(player_index: int) -> void :
	assert (key_hash != Keys.empty_hash)
	var stat_value = Utils.get_stat(key_hash, player_index)
	var value_text = str(stat_value as int)

	_icon.texture = ItemService.get_stat_small_icon(key_hash)
	_label.text = key

	var dodge_cap = RunData.get_player_effect(Keys.dodge_cap_hash, player_index)
	var curse_cap = RunData.get_player_effect(Keys.curse_cap_hash, player_index)
	var hp_cap = RunData.get_player_effect(Keys.hp_cap_hash, player_index)
	var speed_cap = RunData.get_player_effect(Keys.speed_cap_hash, player_index)
	var crit_chance_cap = RunData.get_player_effect(Keys.crit_chance_cap_hash, player_index)

	if key_hash == Keys.stat_dodge_hash and (dodge_cap < stat_value or dodge_cap < 60):
		value_text += " | " + str(dodge_cap as int)
	elif key_hash == Keys.stat_max_hp_hash and hp_cap < Utils.LARGE_NUMBER:
		value_text += " | " + str(hp_cap as int)
	elif key_hash == Keys.stat_speed_hash and speed_cap < Utils.LARGE_NUMBER:
		value_text += " | " + str(speed_cap as int)
	elif key_hash == Keys.stat_crit_chance_hash and crit_chance_cap < Utils.LARGE_NUMBER:
		value_text += " | " + str(crit_chance_cap as int)
	elif key_hash == Keys.stat_curse_hash and stat_value < 0.0:
		value_text += " | " + str(curse_cap as int)

	_value.text = value_text

	if color_override != Color.BLACK:
		_label.add_theme_color_override("font_color", color_override)
		_value.add_theme_color_override("font_color", color_override)
	elif stat_value > 0:
		_label.add_theme_color_override("font_color", ProgressData.settings.color_positive)
		_value.add_theme_color_override("font_color", ProgressData.settings.color_positive)
	elif stat_value < 0:
		_label.add_theme_color_override("font_color", ProgressData.settings.color_negative)
		_value.add_theme_color_override("font_color", ProgressData.settings.color_negative)
	else:
		_label.add_theme_color_override("font_color", Color.WHITE)
		_value.add_theme_color_override("font_color", Color.WHITE)


func _on_StatContainer_focus_entered():
	_on_focused_or_hovered("focused", self)


func _on_StatContainer_focus_exited():
	_on_unfocused_or_unhovered("unfocused", self)


func _on_Label_mouse_entered():
	_on_focused_or_hovered("hovered", _label)


func _on_Label_mouse_exited():
	_on_unfocused_or_unhovered("unhovered", _label)


func _on_Label_focus_entered():
	_on_focused_or_hovered("focused", _label)


func _on_Label_focus_exited():
	_on_unfocused_or_unhovered("unfocused", _label)


func _on_focused_or_hovered(signal_name: String, target: Control):
	var player_index = FocusEmulatorSignal.get_player_index(target)
	if player_index < 0:
		push_error("Focus emulator signal not triggered")
		return

	_apply_focus_theme(player_index)
	emit_signal(signal_name, self, key, Utils.get_stat(key_hash, player_index), player_index)


func _on_unfocused_or_unhovered(signal_name: String, target: Control):
	remove_theme_stylebox_override("panel")

	var player_index = FocusEmulatorSignal.get_player_index(target)
	if player_index < 0:
		push_error("Focus emulator signal not triggered")
		return

	emit_signal(signal_name, player_index)


func _apply_focus_theme(player_index: int) -> void :
	var stylebox_override = get_theme_stylebox("panel").duplicate()

	if RunData.is_coop_run:
		stylebox_override.draw_center = true
		CoopService.change_stylebox_for_player(stylebox_override, player_index)
	else:
		stylebox_override.border_color = _label.get_theme_color("font_color")

	add_theme_stylebox_override("panel", stylebox_override)
