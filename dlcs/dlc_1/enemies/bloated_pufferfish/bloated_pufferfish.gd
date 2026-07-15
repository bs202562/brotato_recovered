class_name Bloated_Pufferfish
extends Enemy

@export var projectile_shader := preload("res://resources/shaders/hue_shift_shadermat.tres")

@export var pop_single_sound: Resource
@onready var _death_shoot_projectiles_behavior = $DeathShootProjectilesBehavior

var shoot_projs_on_death = true
var shoot_cross_projs_on_death = true
const PENDING_BEFORE_DIE_DURATION = 0.5

func _ready() -> void :
	super._ready() # 4.x 移植: Godot 3 自动调用父类虚函数，4.x 需显式调用
	_death_shoot_projectiles_behavior.init(self)
	_all_attack_behaviors.push_back(_death_shoot_projectiles_behavior)

func respawn() -> void :
	super.respawn()
	shoot_projs_on_death = true
	shoot_cross_projs_on_death = true


func _on_Hurtbox_area_entered(hitbox: Area2D) -> void :

	if hitbox.from != null and is_instance_valid(hitbox.from):
		if hitbox.from is RangedWeapon:
			shoot_projs_on_death = true
			shoot_cross_projs_on_death = false
		elif hitbox.from is MeleeWeapon:
			shoot_projs_on_death = false
			shoot_cross_projs_on_death = true
		elif hitbox.from is Pet:
			shoot_projs_on_death = hitbox.from.shoot_projectiles

	super._on_Hurtbox_area_entered(hitbox)


func die(args = Utils.default_die_args) -> void :
	if Utils.get_scene_node()._wave_timer.time_left > PENDING_BEFORE_DIE_DURATION:
		cleaning_up = args.cleaning_up
		if not cleaning_up:
			if shoot_projs_on_death:
				SoundManager2D.play(pop_single_sound, global_position, 5, 0.3, true)
				set_attack_behavior_damage(_death_shoot_projectiles_behavior)
				_death_shoot_projectiles_behavior.number_projectiles = 8
				_death_shoot_projectiles_behavior.shoot()
				current_stats.speed = 0.0
			if shoot_cross_projs_on_death:
				SoundManager2D.play(pop_single_sound, global_position, 5, 0.3, true)
				set_attack_behavior_damage(_death_shoot_projectiles_behavior)
				_death_shoot_projectiles_behavior.number_projectiles = 4
				_death_shoot_projectiles_behavior.shoot()
				current_stats.speed = 0.0

		var charmed_by_player_index = get_charmed_by_player_index()

		super.die(args)

		if shoot_cross_projs_on_death:
			return

		await get_tree().create_timer(PENDING_BEFORE_DIE_DURATION).timeout

		if not _entity_spawner_ref._main._cleaning_up:
			if shoot_projs_on_death:

				var _original_shooting_collision_layer = _death_shoot_projectiles_behavior.custom_collision_layer
				var _original_shooting_material = _death_shoot_projectiles_behavior.custom_sprite_material

				if charmed_by_player_index != - 1:
					_death_shoot_projectiles_behavior.custom_collision_layer = Utils.PET_PROJECTILES_BIT
					var new_shader: = projectile_shader.duplicate()
					new_shader.set_shader_parameter("hue", Utils.CHARM_COLOR.h)
					_death_shoot_projectiles_behavior.custom_sprite_material = new_shader

				SoundManager2D.play(pop_single_sound, global_position, 5, 0.3, true)
				set_attack_behavior_damage(_death_shoot_projectiles_behavior)
				_death_shoot_projectiles_behavior.number_projectiles = 5
				_death_shoot_projectiles_behavior.shoot()

				if charmed_by_player_index != - 1:
					_death_shoot_projectiles_behavior.custom_collision_layer = _original_shooting_collision_layer
					_death_shoot_projectiles_behavior.custom_sprite_material = _original_shooting_material


	else:
		super.die(args)

