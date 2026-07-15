class_name MenuEndRun
extends VBoxContainer

signal cancel_button_pressed

var confirm_button_pressed = false
onready var focus_before_created: Control = get_focus_owner()

func init() -> void :
	focus_before_created = get_focus_owner()
	$Buttons / ConfirmButton.grab_focus()

func _input(event):
	if self.visible and event.is_action_released("ui_cancel"):
		focus_before_created.grab_focus()
		emit_signal("cancel_button_pressed")
		get_tree().set_input_as_handled()

func _on_CancelButton_pressed() -> void :
	focus_before_created.grab_focus()
	emit_signal("cancel_button_pressed")


func _on_ConfirmButton_pressed() -> void :
	if confirm_button_pressed:
		return

	confirm_button_pressed = true
	RunData.apply_end_run()
