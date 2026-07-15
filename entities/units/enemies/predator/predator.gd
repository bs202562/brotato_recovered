extends Boss

@onready var pivot = $Pivot


func _ready():
	super._ready() # 4.x 移植: Godot 3 自动调用父类虚函数，4.x 需显式调用
	for child in pivot.get_children():
		register_additional_projectile(child)


func on_state_changed(new_state: int) -> void :
	super.on_state_changed(new_state)
	if new_state == 0 and pivot != null and is_instance_valid(pivot):
		pivot.rotation_speed *= 1.25


func die(args = Utils.default_die_args) -> void :
	super.die(args)
	pivot.queue_free()
