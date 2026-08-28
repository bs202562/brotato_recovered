class_name MenuCredits
extends Control

signal back_button_pressed

onready var _back_button = $"%BackButton"
onready var _names: RichTextLabel = $"%Names"
onready var focus_before_created: Control = get_focus_owner()

func init() -> void :
	focus_before_created = get_focus_owner()
	_back_button.grab_focus()

func _input(event):
	if self.visible and event.is_action_released("ui_cancel"):
		_on_BackButton_pressed()

func _on_BackButton_pressed() -> void :
	focus_before_created.grab_focus()
	emit_signal("back_button_pressed")
