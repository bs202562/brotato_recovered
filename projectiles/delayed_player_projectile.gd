class_name DelayedPlayerProjectile
extends PlayerProjectile


var delay = randf_range(0.0, 3.0)


func shoot() -> void :
	super.shoot()
	_hitbox.disable()


func _physics_process(delta: float) -> void :
	if _hitbox.is_disabled():
		delay -= 60 * delta
		if delay <= 0:
			_hitbox.enable()

	super._physics_process(delta) # 4.x 移植: Godot 3 自动调用父类虚函数，4.x 需显式调用（_physics_process 为子类优先）
