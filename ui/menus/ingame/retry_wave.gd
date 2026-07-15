class_name MenuRetryWave
extends VBoxContainer

var confirm_button_pressed = false
var cancel_button_pressed = false

onready var _focus_emulator = $FocusEmulator
onready var _confirm_button = $"%ConfirmButton"
onready var _label_number_retry = $"%Label_number_retry"
onready var _retry_wave_container = $"%Retry_WaveContainer" as Container
onready var _ok_button = $"%OkButton" as Button


func _ready() -> void :
	_ok_button.visible = not ProgressData.settings.retry_wave
	_retry_wave_container.visible = ProgressData.settings.retry_wave
	_focus_emulator.set_process_input(false)


func show() -> void :
	.show()
	if ProgressData.settings.retry_wave:
		_label_number_retry.text = Text.text("RETRY_NUMBER", [str(RunData.retries)])
		_confirm_button.grab_focus()
	else:
		_ok_button.grab_focus()
	_focus_emulator.set_process_input(true)


func _on_CancelButton_pressed() -> void :
	if cancel_button_pressed:
		return
	cancel_button_pressed = true
	DebugService.log_data("end run...")
	var scene = RunData.get_end_run_scene_path()
	_change_scene(scene)


func _on_ConfirmButton_pressed() -> void :
	if confirm_button_pressed:
		return
	confirm_button_pressed = true

	RunData.reset_to_start_wave_state()
	RunData.retries += 1
	_change_scene(MenuData.game_scene)


func _change_scene(path: String) -> void :
	var _error = get_tree().change_scene(path)
