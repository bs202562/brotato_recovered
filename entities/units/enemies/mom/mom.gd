extends Boss

@onready var _spawning_shooting_behavior = $SpawningShootingBehavior


func _ready() -> void :
	super._ready() # 4.x 移植: Godot 3 自动调用父类虚函数，4.x 需显式调用
	_spawning_shooting_behavior.init(self)
	_all_attack_behaviors.push_back(_spawning_shooting_behavior)


func shoot() -> void :
	super.shoot()

	if _current_state == 0:
		_spawning_shooting_behavior.shoot()
