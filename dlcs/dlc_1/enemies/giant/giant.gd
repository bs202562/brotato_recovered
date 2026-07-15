class_name Giant
extends Boss

@onready var pivot = $Pivot
@onready var pivot2 = $Pivot2


func _ready():
	super._ready() # 4.x 移植: Godot 3 自动调用父类虚函数，4.x 需显式调用
	var specific_direction = Utils.get_rand_element([ - 1, 1])
	pivot.direction = specific_direction
	pivot2.direction = specific_direction

	for child in pivot.get_children():
		register_additional_projectile(child)
	for child in pivot2.get_children():
		register_additional_projectile(child)


func die(args = Utils.default_die_args) -> void :
	super.die(args)
	pivot.queue_free()
	pivot2.queue_free()
