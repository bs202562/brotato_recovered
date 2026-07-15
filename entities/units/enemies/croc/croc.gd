extends Boss

var CHARGING_PROJECTILES_COOLDOWN = 45.0
var current_projectiles_cooldown = 0.0
var current_charging_projectile_behavior = null

@onready var _charging_shoot_projectiles_behavior = $ChargingShootProjectilesBehavior
@onready var _charging_shoot_projectiles_behavior_2 = $ChargingShootProjectilesBehavior2


func _ready() -> void :
	super._ready() # 4.x 移植: Godot 3 自动调用父类虚函数，4.x 需显式调用
	_charging_shoot_projectiles_behavior.init(self)
	_charging_shoot_projectiles_behavior_2.init(self)

	current_charging_projectile_behavior = _charging_shoot_projectiles_behavior

	_all_attack_behaviors.push_back(_charging_shoot_projectiles_behavior)
	_all_attack_behaviors.push_back(_charging_shoot_projectiles_behavior_2)


func _physics_process(delta: float) -> void :
	current_projectiles_cooldown = max(0.0, current_projectiles_cooldown - 60 * delta)

	if _move_locked and current_projectiles_cooldown <= 0.0 and not dead:
		current_projectiles_cooldown = CHARGING_PROJECTILES_COOLDOWN
		current_charging_projectile_behavior.shoot()

	super._physics_process(delta)


func on_state_changed(new_state: int) -> void :
	super.on_state_changed(new_state)

	if new_state == 0:
		current_charging_projectile_behavior = _charging_shoot_projectiles_behavior_2
