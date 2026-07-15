class_name MeleeWeapon
extends Weapon

var next_attack_type: int


func _ready() -> void :
	super._ready() # 4.x 移植: Godot 3 自动调用父类虚函数，4.x 需显式调用（_ready 为基类优先）
	next_attack_type = stats.attack_type


func shoot() -> void :
	super.shoot()

	if stats.alternate_attack_type:
		next_attack_type = MeleeAttackType.THRUST if next_attack_type == MeleeAttackType.SWEEP else MeleeAttackType.SWEEP


func get_max_range() -> int:

	if next_attack_type == MeleeAttackType.THRUST:
		return super.get_max_range()
	else:
		return get_sweep_range(current_stats.max_range)


func get_sweep_range(distance: float) -> int:
	return distance as int


func should_rotate_manual() -> bool:
	return not _is_shooting
