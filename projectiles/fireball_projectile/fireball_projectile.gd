class_name FireballProjectile
extends PlayerProjectile

@onready var burning_particles = $BurningParticles


func shoot() -> void :
	super.shoot()
	burning_particles.restart()


func stop() -> void :
	super.stop()
	burning_particles.emitting = false
