extends Node2D
class_name BulletHell

var player_index = - 1

@export var projectile_scene: PackedScene = preload("res://projectiles/bullet_enemy/enemy_projectile.tscn")
@export var projectile_damage: int = 1
@export var projectile_damage_increase_each_wave: float = 0.0
@export var projectile_speed: float = 300 # (float, 0, 1000)
@export var spawn_rate: float = 1
@export var start_cool_down: float = 0
@export var icon: Texture2D

@export var bullet_generator_groups: Array

@onready var bullets_generator = get_children()
@onready var tick_progression: float = - start_cool_down

func _update_bullet_hell_parameters(_wave, _isElite, _isHorde):
	if (_isElite or _isHorde):
		_wave /= 2.0

	spawn_rate = spawn_rate - (_wave / 20.0)
	projectile_speed = projectile_speed + (_wave * 2.0)
	var base_damage = 1 + projectile_damage_increase_each_wave * (RunData.current_wave - 1)
	projectile_damage = EntityService.get_final_enemy_damage(base_damage, - 50)

