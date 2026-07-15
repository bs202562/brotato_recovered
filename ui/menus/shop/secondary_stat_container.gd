class_name SecondaryStatContainer
extends PanelContainer

signal focused(button, title, value, player_index)
signal unfocused(player_index)

@export var key: String
@export var custom_text_key: String
@export var reverse: bool = false

@onready var key_hash: int = Keys.generate_hash(key.to_lower())

@onready var _label = $HBoxContainer / Label
@onready var _value = $HBoxContainer / Value


func disable_focus() -> void :
	focus_mode = FOCUS_NONE
	_label.focus_mode = FOCUS_NONE


func update_player_stat(player_index: int) -> void :
	
	

	var stat_value = Utils.get_stat(key_hash, player_index)

	
	if key_hash == Keys.structure_attack_speed_hash:
		stat_value = WeaponService.get_structure_attack_speed(player_index)

	var value_text = str(stat_value as int)

	_label.text = custom_text_key if custom_text_key != "" else key
	_value.text = value_text

	if (stat_value > 0 and not reverse) or (stat_value < 0 and reverse):
		_label.modulate = ProgressData.settings.color_positive
		_value.modulate = ProgressData.settings.color_positive
	elif (stat_value < 0 and not reverse) or (stat_value > 0 and reverse):
		_label.modulate = ProgressData.settings.color_negative
		_value.modulate = ProgressData.settings.color_negative
	else:
		_label.modulate = Color.WHITE
		_value.modulate = Color.WHITE


func _on_SecondaryStatContainer_focus_entered():
	var player_index = FocusEmulatorSignal.get_player_index(self)
	if player_index < 0:
		push_error("Focus emulator signal not triggered")
		return
	var text_key = custom_text_key if custom_text_key != "" else key

	
	

	emit_signal("focused", self, text_key, Utils.get_stat(key_hash, player_index), player_index)


func _on_SecondaryStatContainer_focus_exited():
	var player_index = FocusEmulatorSignal.get_player_index(self)
	if player_index < 0:
		push_error("Focus emulator signal not triggered")
		return
	emit_signal("unfocused", player_index)
