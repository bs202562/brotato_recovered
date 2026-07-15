
extends CPUParticles2D
class_name RunningSmoke

@export var take_background_color: bool = true


func _ready() -> void :
	if take_background_color:
		color = RunData.get_background().outline_color


func emit() -> void :
	emitting = true


func stop() -> void :
	emitting = false
