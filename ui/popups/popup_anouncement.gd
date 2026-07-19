# 4.x 移植: 3.x 的 Popup 是 Control,4.x 改成了独立 Window,改用 Control + 手动显隐
extends Control
class_name PopupAnouncement

@onready var _rich_text_description = $"%rich_text_description"
@onready var _validation_button = $"%validation_button"
@onready var focus_before_created: Control = null

func _ready():
	_validation_button.connect("pressed", Callable(self, "_on_validation_button_pressed"))
	_rich_text_description.text = "[center]" + tr(_rich_text_description.text)


func popup_announcement():
	focus_before_created = get_viewport().gui_get_focus_owner()

	show()
	if RunData.is_coop_run:
		Utils._popup = self


func _input(event):
	if visible:
		if event.is_action_released("ui_cancel"):
			_on_validation_button_pressed()
			get_viewport().set_input_as_handled()


func _focus_control(control: Control, player: int = 0) -> void :
	if RunData.is_coop_run:
		if RunData.is_coop_run:
			Utils.focus_player_control(control, player)
	elif is_instance_valid(control):
		control.grab_focus()


func _on_validation_button_pressed():
	_close_popup()


func _close_popup():
	_focus_control(focus_before_created)
	hide()
	if RunData.is_coop_run:
		Utils._popup = null
	hide()
