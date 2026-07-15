extends HBoxContainer
class_name WaveGraph

onready var polygon: Polygon2D = $"%polygon"
onready var graph_container: Container = $"%GraphContainer"
onready var base_stat_label_number: Label = $"%base_stat_label_number"
onready var adding_stat_label_number: Label = $"%adding_stat_label_number"
onready var label_scale_0: Label = $"%scale_0"
onready var label_scale_1: Label = $"%scale_1"
onready var label_scale_2: Label = $"%scale_2"
onready var label_scale_3: Label = $"%scale_3"


func set_graph(base_value: float, adding_value: float, max_scale_value: float, exponential_scale: float = 1) -> void :
	base_stat_label_number.text = str(base_value)
	adding_stat_label_number.text = "+" + str(adding_value)

	var start_from_one: bool = false
	if max_scale_value > 10 and exponential_scale > 1:
		start_from_one = true
	_scale(0, max_scale_value, exponential_scale, start_from_one)
	_scale(1, max_scale_value, exponential_scale, start_from_one)
	_scale(2, max_scale_value, exponential_scale, start_from_one)
	_scale(3, max_scale_value, exponential_scale, start_from_one)
	for wave_index in 21:
		var value: float = base_value + (adding_value * float(wave_index))
		polygon.polygon[wave_index].y = max(0, _y_position_in_graph(value, max_scale_value, exponential_scale, start_from_one))


func _y_position_in_graph(value: float, max_scale_value: float, exponential_scale: float = 1, start_from_one: bool = false) -> float:
	var linear_position: float
	if start_from_one:
		linear_position = (value - 1) / (max_scale_value - 1)
	else:
		linear_position = value / max_scale_value
	var exponential_position: float = pow(linear_position, 1 / exponential_scale)
	return (1 - exponential_position) * graph_container.rect_size.y


func _scale(label_index: int, max_scale_value: float, exponential_scale: float = 1, start_from_one: bool = false) -> void :
	var label_to_change: Label
	match label_index:
		0:
			label_to_change = label_scale_0
		1:
			label_to_change = label_scale_1
		2:
			label_to_change = label_scale_2
		3:
			label_to_change = label_scale_3

	var linear_position: float = (float(label_index) + 1) / 4
	var exponential_position: float = pow(linear_position, exponential_scale)

	label_to_change.text = String(int(exponential_position * max_scale_value))
