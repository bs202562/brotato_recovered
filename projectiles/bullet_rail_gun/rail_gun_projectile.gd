class_name RailGunProjectile
extends PlayerProjectile

@onready var _particles2D: = $"%CPUParticles2D" as CPUParticles2D

func _return_to_pool() -> void :
	super._return_to_pool()

	_particles2D.restart()
	_particles2D.emitting = false

func shoot() -> void :
	super.shoot()
	_sprite.modulate.a = ProgressData.settings.projectile_opacity
	_particles2D.emitting = true
