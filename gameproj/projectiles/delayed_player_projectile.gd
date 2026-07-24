class_name DelayedPlayerProjectile
extends PlayerProjectile


var delay = rand_range(0.0, 3.0)


func shoot() -> void :
	.shoot()
	_hitbox.disable()


func _physics_process(delta: float) -> void :
	if _hitbox.is_disabled():
		delay -= 60 * delta
		if delay <= 0:
			_hitbox.enable()
