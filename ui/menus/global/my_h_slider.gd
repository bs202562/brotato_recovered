class_name MyHSlider
extends HSlider

@export var focus_entered_sound: Resource = preload("res://ui/sounds/button_focus.wav")
@export var value_change_sound: Resource = preload("res://ui/sounds/button_focus.wav")


func _ready() -> void :
	var _error_focus = connect("focus_entered", Callable(self, "on_focus_entered"))


func on_focus_entered() -> void :
	if focus_entered_sound != null:
		SoundManager.play(focus_entered_sound, - 10, 0.2)


func on_pressed() -> void :
	if value_change_sound != null:
		SoundManager.play(value_change_sound, - 10, 0.2)


func _on_HSlider_value_changed(_value: float) -> void :
	if value_change_sound != null:
		SoundManager.play(value_change_sound, - 10, 0.2)
