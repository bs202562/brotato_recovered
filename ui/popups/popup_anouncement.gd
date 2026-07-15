extends Popup
class_name PopupAnouncement

onready var _rich_text_description = $"%rich_text_description"
onready var _validation_button = $"%validation_button"
onready var focus_before_created: Control = null

func _ready():
	_validation_button.connect("pressed", self, "_on_validation_button_pressed")
	_rich_text_description.bbcode_text = "[center]" + tr(_rich_text_description.bbcode_text)


func popup(bounds: Rect2 = Rect2(0, 0, 0, 0)):
	focus_before_created = get_focus_owner()

	.popup()
	if RunData.is_coop_run:
		Utils._popup = self


func _input(event):
	if visible:
		if event.is_action_released("ui_cancel"):
			_on_validation_button_pressed()
			get_tree().set_input_as_handled()


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
