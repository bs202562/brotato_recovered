class_name Narwhal
extends Enemy

@onready var _charging_shoot_projectiles_behavior = $ChargingShootProjectilesBehavior

var shot = false

func _ready() -> void :
	super._ready() # 4.x 移植: Godot 3 自动调用父类虚函数，4.x 需显式调用
	_charging_shoot_projectiles_behavior.init(self)
	_all_attack_behaviors.push_back(_charging_shoot_projectiles_behavior)


func respawn() -> void :
	super.respawn()
	shot = false


func _physics_process(_delta: float) -> void :
	if _move_locked and not shot and not dead:
		shot = true
		_charging_shoot_projectiles_behavior.shoot()
	elif not _move_locked:
		shot = false

	super._physics_process(_delta)
