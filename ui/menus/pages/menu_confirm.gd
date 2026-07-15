class_name MenuConfirm
extends VBoxContainer

signal cancel_button_pressed
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
	
	get_tree().paused = false
	if RunData.wave_in_progress:
		var value = RunData.wave_timer.time_left
		if not ChallengeService.is_challenge_completed(ChallengeService.chal_hourglass_hash) and value < ChallengeService.get_chal(ChallengeService.chal_hourglass_hash).value:
			ProgressData.data.chal_hourglass_quit_wave = true
	ProgressData.reset_dlc_resources_to_active_dlcs()
	var _error = get_tree().change_scene(MenuData.title_screen_scene)
	ProgressData.end_activity(false)

