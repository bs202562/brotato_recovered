class_name UIDimScreen
extends ColorRect

var _tween: Tween = null


func dim() -> void :
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "color:a", 0.5, 1).from(0).set_trans(Tween.TRANS_LINEAR)


func color_for_player(player_index: int) -> void :
	var color_value: = color.v
	var player_color = CoopService.get_player_color(player_index, color_value)
	player_color.s *= 0.5
	player_color.a = color.a
	color = player_color
