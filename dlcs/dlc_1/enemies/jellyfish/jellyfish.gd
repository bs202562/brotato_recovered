class_name Jellyfish
extends Boss

@onready var pivot = $Pivot
@onready var pivot2 = $Pivot2
@onready var pivot3 = $Pivot3
@onready var pivot4 = $Pivot4

@onready var second_phase_shooting_behavior = $SecondPhaseShootingBehavior


func _ready():
	super._ready() # 4.x 移植: Godot 3 自动调用父类虚函数，4.x 需显式调用
	var specific_direction = Utils.get_rand_element([ - 1, 1])
	pivot.direction = specific_direction
	pivot2.direction = specific_direction
	pivot3.direction = specific_direction
	pivot4.direction = specific_direction
	second_phase_shooting_behavior.init(self)
	_all_attack_behaviors.push_back(second_phase_shooting_behavior)

	for child in pivot.get_children():
		register_additional_projectile(child)
	for child in pivot2.get_children():
		register_additional_projectile(child)
	for child in pivot3.get_children():
		register_additional_projectile(child)
	for child in pivot4.get_children():
		register_additional_projectile(child)


func die(args = Utils.default_die_args) -> void :
	super.die(args)
	pivot.queue_free()
	pivot2.queue_free()
	pivot3.queue_free()
	pivot4.queue_free()


func on_state_changed(new_state: int) -> void :
	super.on_state_changed(new_state)

	if new_state == 0:
		reset_speed_stat( - 50)
		var _e = _states[0][3].connect("finished_shooting", Callable(self, "on_second_phase_shot"))


func on_second_phase_shot() -> void :
	second_phase_shooting_behavior.shoot()
