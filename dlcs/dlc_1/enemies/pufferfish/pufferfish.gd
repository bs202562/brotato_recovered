class_name Pufferfish
extends Enemy


@export var pop_single_sound: Resource
@onready var _death_shoot_projectiles_behavior = $DeathShootProjectilesBehavior

var shoot_projs_on_death = true


func _ready() -> void :
	super._ready() # 4.x 移植: Godot 3 自动调用父类虚函数，4.x 需显式调用
	_death_shoot_projectiles_behavior.init(self)
	_all_attack_behaviors.push_back(_death_shoot_projectiles_behavior)

func respawn() -> void :
	super.respawn()
	shoot_projs_on_death = true


func _on_Hurtbox_area_entered(hitbox: Area2D) -> void :

	if hitbox.from != null and is_instance_valid(hitbox.from):
		if hitbox.from is RangedWeapon:
			shoot_projs_on_death = true
		elif hitbox.from is MeleeWeapon:
			shoot_projs_on_death = false
		elif hitbox.from is Pet:
			shoot_projs_on_death = hitbox.from.shoot_projectiles

	super._on_Hurtbox_area_entered(hitbox)


func die(args = Utils.default_die_args) -> void :
	if Utils.get_scene_node()._wave_timer.time_left > 0.5:
		cleaning_up = args.cleaning_up
		if not cleaning_up:
			if shoot_projs_on_death:
				SoundManager2D.play(pop_single_sound, global_position, 5, 0.3, true)
				set_attack_behavior_damage(_death_shoot_projectiles_behavior)
				_death_shoot_projectiles_behavior.number_projectiles = 8
				_death_shoot_projectiles_behavior.shoot()
	super.die(args)
