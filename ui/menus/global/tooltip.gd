extends PanelContainer

@onready var _label = $Label

var text : get = _get_text, set = _set_text


func _set_text(value):
	_label.text = value
	
	call_deferred("set", "size", Vector2.ZERO)


func _get_text():
	return _label.text
