extends Boss

onready var pivot = $Pivot


func _ready():
	for child in pivot.get_children():
		register_additional_projectile(child)


func on_state_changed(new_state: int) -> void :
	.on_state_changed(new_state)
	if new_state == 0 and pivot != null and is_instance_valid(pivot):
		pivot.rotation_speed *= 1.25


func die(args: = Utils.default_die_args) -> void :
	.die(args)
	pivot.queue_free()
