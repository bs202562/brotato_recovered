extends AnimatedSprite2D

signal is_finished(object) # 4.x 移植: 原名 finished 统一重命名（与 PooledParticles 保持一致）



func play(anim: StringName = &"", custom_speed: float = 1.0, from_end: bool = false) -> void :
	show()
	super.play(anim, custom_speed, from_end)


func _on_HitEffect_animation_finished() -> void :
	hide()
	stop()
	frame = 0
	emit_signal("is_finished", self)
