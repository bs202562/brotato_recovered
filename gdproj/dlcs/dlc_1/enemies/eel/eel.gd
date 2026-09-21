class_name Eel
extends Boss

export (PackedScene) var pivots_scene

var current_projectiles_cooldown = 0.0
var shoot_on_change_phase_behavior_cd = 99999999
var shoot_on_charge_last_phase_behavior_cd = 99999999

onready var _charging_shoot_projectiles_behavior = $ChargingShootProjectilesBehavior
onready var _shoot_on_change_phase_behavior = $ShootOnChangePhaseBehavior
onready var _shoot_on_charge_last_phase_behavior = $ShootOnChargeLastPhaseBehavior

var pivots


func _ready() -> void :
	_charging_shoot_projectiles_behavior.init(self)
	_shoot_on_change_phase_behavior.init(self)
	_shoot_on_charge_last_phase_behavior.init(self)
	_all_attack_behaviors.push_back(_charging_shoot_projectiles_behavior)
	_all_attack_behaviors.push_back(_shoot_on_change_phase_behavior)
	_all_attack_behaviors.push_back(_shoot_on_charge_last_phase_behavior)


func _physics_process(delta: float) -> void :
	current_projectiles_cooldown = max(0.0, current_projectiles_cooldown - 60 * delta)
	shoot_on_change_phase_behavior_cd = max(0.0, shoot_on_change_phase_behavior_cd - 60 * delta)
	shoot_on_charge_last_phase_behavior_cd = max(0.0, shoot_on_charge_last_phase_behavior_cd - 60 * delta)

	if _move_locked and current_projectiles_cooldown <= 0.0 and not dead:
		current_projectiles_cooldown = _charging_shoot_projectiles_behavior.cooldown
		_charging_shoot_projectiles_behavior.shoot()

	if shoot_on_change_phase_behavior_cd <= 0.0 and not dead:
		_shoot_on_change_phase_behavior.shoot()
		shoot_on_change_phase_behavior_cd = Utils.LARGE_NUMBER

	if shoot_on_charge_last_phase_behavior_cd <= 0.0 and not dead and _move_locked:
		_shoot_on_charge_last_phase_behavior.shoot()
		shoot_on_charge_last_phase_behavior_cd = _shoot_on_charge_last_phase_behavior.cooldown


func on_state_changed(new_state: int) -> void :
	.on_state_changed(new_state)

	if new_state == 0:
		reset_speed_stat(50)
		shoot_on_change_phase_behavior_cd = 30.0
	elif new_state == 1:
		reset_speed_stat(0)
		pivots = pivots_scene.instance()
		add_child(pivots)
		for child in pivots.get_bullets():
			register_additional_projectile(child)
		shoot_on_change_phase_behavior_cd = 30.0
		_current_attack_behavior._current_cd = 75.0


func die(args: = Utils.default_die_args) -> void :
	.die(args)

	if pivots:
		pivots.free_pivots()
