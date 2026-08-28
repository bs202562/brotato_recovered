class_name FireballProjectile
extends PlayerProjectile

onready var burning_particles = $BurningParticles


func shoot() -> void :
	.shoot()
	burning_particles.restart()


func stop() -> void :
	.stop()
	burning_particles.emitting = false
