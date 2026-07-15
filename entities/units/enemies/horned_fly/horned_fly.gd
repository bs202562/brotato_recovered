extends Enemy

@export var proj_chance: float = 0.25


func _on_Hurtbox_area_entered(hitbox: Area2D) -> void :
	super._on_Hurtbox_area_entered(hitbox)

	if hitbox.from != null and is_instance_valid(hitbox.from):
		if (hitbox.from is RangedWeapon or (hitbox.from is Pet and hitbox.from.shoot_projectiles)) and Utils.get_chance_success(proj_chance):
			_attack_behavior.call_deferred("shoot")

