extends Enemy

var current_projectiles_cooldown = 0.0

@onready var _charging_shoot_projectiles_behavior = $ChargingShootProjectilesBehavior


func _ready() -> void :
	super._ready() # 4.x 移植: Godot 3 自动调用父类虚函数，4.x 需显式调用
	_charging_shoot_projectiles_behavior.init(self)
	_all_attack_behaviors.push_back(_charging_shoot_projectiles_behavior)


func respawn() -> void :
	super.respawn()
	current_projectiles_cooldown = 0.0


func _physics_process(delta: float) -> void :
	current_projectiles_cooldown = max(0.0, current_projectiles_cooldown - 60 * delta)

	if _move_locked and current_projectiles_cooldown <= 0.0 and not dead:
		current_projectiles_cooldown = _charging_shoot_projectiles_behavior.cooldown
		_charging_shoot_projectiles_behavior.shoot()

	super._physics_process(delta)
