class_name EnemyProjectile
extends Projectile


func _ready() -> void :
	super._ready() # 4.x 移植: Godot 3 自动调用父类虚函数，4.x 需显式调用（_ready 为基类优先；shoot() 依赖父类初始化的 _original_hitbox_disabled）
	shoot()


func shoot() -> void :
	super.shoot()

	if not _sprite.material:
		_sprite.material = Utils.projectile_outline_shadermat
	if ProgressData.settings.projectile_highlighting:
		_sprite.material.set_shader_parameter("texture_size", _sprite.texture.get_size())
	else:
		_sprite.material.set_shader_parameter("texture_size", Vector2(0, 0))


func _on_Hitbox_hit_something(_thing_hit: Node, _damage_dealt: int) -> void :
	stop()
