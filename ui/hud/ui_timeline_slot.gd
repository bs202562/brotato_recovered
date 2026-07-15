extends VBoxContainer
class_name UITimelineSlot

@onready var _label: Label = $"%label"
@onready var _point_text: TextureRect = $"%point_text"
@onready var _event_icon: TextureRect = $"%event_icon"
@onready var _second_event_icon: TextureRect = $"%second_event_icon"

var value: int

func _set_slot(_value: int, event_icons = null, color: Color = Color(1, 1, 1, 1), shadow_icon: bool = false):
	value = _value
	_set_color(color)
	if value % 5 == 0 or event_icons.size() > 0:
		_point_text.custom_minimum_size = Vector2(45, 45)
		_label.text = str(value)
		_label.modulate.a = 1
	else:
		_point_text.custom_minimum_size = Vector2(32, 32)
		_label.modulate.a = 0

	if (event_icons.size() > 0):
		_event_icon.texture = event_icons[0][0]
		if event_icons[0][1] != null:
			_event_icon.material = event_icons[0][1]
	else:
		_event_icon.texture = null
	if (event_icons.size() > 1):
		_second_event_icon.texture = event_icons[1][0]
		if event_icons[1][1] != null:
			_event_icon.material = event_icons[1][1]
	else:
		_second_event_icon.visible = false

	_point_text.visible = _event_icon.texture == null

	if shadow_icon:
		_event_icon.modulate = Color(1, 1, 1, 0.7)
	else:
		_event_icon.modulate = Color(1, 1, 1, 1)

func _set_color(color: Color):
	_point_text.modulate = color
	_label.modulate.r = color.r
	_label.modulate.g = color.g
	_label.modulate.b = color.b


func _up_icon():
	_event_icon.global_position.y -= 64
