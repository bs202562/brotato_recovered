class_name CoopJoinProgress
extends Control


var progress_color: Color: get = _get_progress_color, set = _set_progress_color
func _set_progress_color(value: Color) -> void :
	_join_progress.tint_progress = value
func _get_progress_color() -> Color:
	return _join_progress.tint_progress


var inner_color: Color: get = _get_inner_color, set = _set_inner_color
func _set_inner_color(value: Color) -> void :
	_join_progress.tint_under = value
func _get_inner_color() -> Color:
	return _join_progress.tint_under



var progress: float: get = _get_progress, set = _set_progress
func _set_progress(value: float) -> void :
	_join_progress.value = value
func _get_progress() -> float:
	return _join_progress.value


var text: String: get = _get_text, set = _set_text
func _set_text(value: String) -> void :
	_player_label.text = value
func _get_text() -> String:
	return _player_label.text


@onready var _join_progress: TextureProgressBar = $"%JoinProgress"
@onready var _player_label: Label = $"%PlayerLabel"
