class_name Popin
extends PanelContainer

signal confirm

var _confirm_button: Button
var _description: Label
var _focus_emulator: FocusEmulator

func _ready() -> void :
	_confirm_button = get_node("Container/Content/ConfirmButton")
	_description = get_node("Container/Content/Description")
	_focus_emulator = get_node("FocusEmulator")
	_confirm_button.connect("pressed", Callable(self, "_on_ConfirmButton_pressed"))

func _on_ConfirmButton_pressed() -> void :
	emit_signal("confirm")

func setContent(desc: String, confirmLabel):
	_description.text = tr(desc);
	_confirm_button.text = tr(confirmLabel);
	_confirm_button.grab_focus()
	_focus_emulator.set_process_input(true)
	_focus_emulator.player_index = 0
	
func clean():
	_focus_emulator.set_process_input(false)
	_focus_emulator.player_index = - 1
