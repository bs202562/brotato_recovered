class_name Fireball
extends RangedWeapon

@onready var burn_particles = $"%BurningParticles"

func update_sprite(new_sprite: Texture2D) -> void :
	super.update_sprite(new_sprite)

	if is_instance_valid(burn_particles):
		burn_particles.emitting = not burn_particles.emitting
