class_name CoopButton
extends CheckButton

signal coop_initialized(active)


func init() -> void :
	button_pressed = RunData.play_mode != RunData.PlayMode.SOLO
	
	
	var _e = connect("toggled", Callable(self, "_on_toggled"))


func _on_toggled(button_pressed: bool) -> void :
	RunData.play_mode = RunData.PlayMode.COOP if button_pressed else RunData.PlayMode.SOLO
	emit_signal("coop_initialized", button_pressed)
