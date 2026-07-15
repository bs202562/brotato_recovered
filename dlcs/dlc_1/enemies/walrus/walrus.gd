class_name Walrus
extends Enemy

@onready var _charging_shoot_projectiles_behavior = $ChargingShootProjectilesBehavior


func _ready() -> void :
	super._ready() # 4.x 移植: Godot 3 自动调用父类虚函数，4.x 需显式调用
	_charging_shoot_projectiles_behavior.init(self)
	_all_attack_behaviors.push_back(_charging_shoot_projectiles_behavior)
