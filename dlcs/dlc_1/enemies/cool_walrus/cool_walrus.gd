class_name Cool_Walrus
extends Enemy

onready var _charging_shoot_projectiles_behavior = $ChargingShootProjectilesBehavior


func _ready() -> void :
	_charging_shoot_projectiles_behavior.init(self)
	_all_attack_behaviors.push_back(_charging_shoot_projectiles_behavior)
