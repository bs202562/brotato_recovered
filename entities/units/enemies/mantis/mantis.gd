extends Boss

var CHARGING_PROJECTILES_COOLDOWN = 15.0
var current_projectiles_cooldown = 0.0

@onready var _charging_shoot_projectiles_behavior = $ChargingShootProjectilesBehavior


func _ready() -> void :
	super._ready() # 4.x 移植: Godot 3 自动调用父类虚函数，4.x 需显式调用
	_charging_shoot_projectiles_behavior.init(self)
	_all_attack_behaviors.push_back(_charging_shoot_projectiles_behavior)


func _physics_process(delta: float) -> void :
	current_projectiles_cooldown = max(0.0, current_projectiles_cooldown - 60 * delta)

	if _move_locked and current_projectiles_cooldown <= 0.0 and not dead:
		current_projectiles_cooldown = CHARGING_PROJECTILES_COOLDOWN
		_charging_shoot_projectiles_behavior.shoot()

	super._physics_process(delta)
