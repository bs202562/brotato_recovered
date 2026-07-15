class_name RailGun
extends RangedWeapon

@export var bullet_color_gradient: Gradient

@onready var _one_second_timer: Timer = $OneSecondTimer
@onready var _modulate_color_sprite: Sprite2D = $"%modulate_color_sprite"
var _one_second_timeouts: = 0
var duplicated_stats: RangedWeaponStats = null
var args: = WeaponServiceInitStatsArgs.new()
var on_hit_args: = WeaponServiceInitStatsArgs.new()
var base_damage: float = 0
var bonus_damage: float = 0
var interval_count: float = 0
var mat_bullet: Material

func _ready() -> void :
	super._ready() # 4.x 移植: Godot 3 自动调用父类虚函数，4.x 需显式调用（_ready 为基类优先；_parent 由 Weapon._ready 初始化）
	_one_second_timer.start()
	_one_second_timeouts = 0
	var error = _parent.connect("took_damage", Callable(self, "_player_took_damage"))

	base_damage = stats.damage
	bonus_damage = 0
	interval_count = 0

	emit_signal("tracked_value_set", 0)

	_modulate_color_sprite.modulate = bullet_color_gradient.sample(0.0)


func init_stats(at_wave_begin: bool = true) -> void :
	args.sets = weapon_sets
	args.effects = effects
	base_damage = stats.damage

	if at_wave_begin and duplicated_stats == null:
		duplicated_stats = stats.duplicate()

	duplicated_stats.damage = base_damage + bonus_damage

	current_stats = WeaponService.init_ranged_stats(duplicated_stats, player_index, false, args)
	_stats_every_x_shots = WeaponService.init_stats_every_x_projectiles(duplicated_stats, player_index, args)
	for x_shot_stats in _stats_every_x_shots.values():
		x_shot_stats.burning_data.from = self

	_hitbox.projectiles_on_hit = []

	for effect in effects:
		if effect is ProjectilesOnHitEffect:
			var weapon_stats = WeaponService.init_ranged_stats(effect.weapon_stats, player_index, true, on_hit_args)
			_hitbox.projectiles_on_hit = [effect.value, weapon_stats, effect.auto_target_enemy]

	current_stats.burning_data.from = self

	var hitbox_args: = Hitbox.HitboxArgs.new().set_from_weapon_stats(current_stats)

	_hitbox.effect_scale = current_stats.effect_scale
	_hitbox.set_damage(current_stats.damage, hitbox_args)
	_hitbox.speed_percent_modifier = current_stats.speed_percent_modifier
	_hitbox.effects = effects
	_hitbox.from = self

	if at_wave_begin:
		_current_cooldown = get_next_cooldown(at_wave_begin)

	reset_cooldown()
	_range_shape.shape.radius = current_stats.max_range + DETECTION_RANGE

func _player_took_damage(_unit: Unit, value: int, _knockback_direction: Vector2, _is_crit: bool, _is_dodge: bool, _is_protected: bool, _armor_did_something: bool, _args: TakeDamageArgs, _hit_type: int, _is_one_shot: bool) -> void :
	if _is_protected or _is_dodge:
		return

	for effect in effects:
		if effect is PlayerNoHitEffect:
			emit_signal("tracked_value_set", 0)

	_one_second_timeouts = 0
	bonus_damage = 0
	interval_count = 0
	init_stats(false)

func _on_OneSecondTimer_timeout():
	_one_second_timeouts += 1

	for effect in effects:
		if effect is PlayerNoHitEffect:
			var value: int = effect.value
			var interval: int = effect.interval


			if _one_second_timeouts % interval == 0:
				interval_count = _one_second_timeouts / interval
				bonus_damage = value * interval_count
				init_stats(false)
				emit_signal("tracked_value_set", bonus_damage)

			break

	_modulate_color_sprite.modulate = bullet_color_gradient.sample(interval_count / 8.0)

func on_projectile_shot(projectile: Node2D) -> void :
	super.on_projectile_shot(projectile)
	if not is_instance_valid(projectile):
		return

	var col: Color = bullet_color_gradient.sample(interval_count / 8.0)
	projectile._sprite.material.set("shader_param/color_A", col)
	projectile.get_node("%CPUParticles2D").modulate = col
