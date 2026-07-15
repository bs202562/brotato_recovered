extends Label

var wave_timer: Timer


func _ready() -> void :
	set_message_translation(false)


func _process(_delta: float) -> void :
	if wave_timer != null and is_instance_valid(wave_timer):
		text = str(ceil(wave_timer.time_left))


func change_color(color: Color) -> void :
	modulate = color
