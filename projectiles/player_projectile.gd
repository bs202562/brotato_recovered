class_name PlayerProjectile
extends Projectile

const PROJECTILE_ADDITIONAL_DISTANCE = 100
const PROJECTILE_HALF_ADDITIONAL_DISTANCE = 50
const INFINITE_RANGE = 10000
const PHYSICS_FPS: float = 1.0 / 60.0

@export var rotation_speed: int = 0

var spawn_position: Vector2



var _weapon_stats: Resource
var _piercing: = 0
var _bounce: = 0
var _max_range: = 0
var _time_until_max_range: float

var player_index: int
func _get_player_index() -> int:
	return _hitbox.from.player_index




func _physics_process(delta: float) -> void :
	if rotation_speed != 0:
		rotation_degrees += 25

	if _time_until_max_range <= 0:
		stop()
	_time_until_max_range -= delta

	super._physics_process(delta) # 4.x 移植: Godot 3 自动调用父类虚函数，4.x 需显式调用（_physics_process 为子类优先）


func shoot_ex(p_from: Node, 
		pos: Vector2, 
		p_velocity: Vector2, 
		p_rotation: float, 
		p_weapon_stats: WeaponStats, 
		damage_tracking_key: int, 
		effects: Array, 
		hitbox_args: Hitbox.HitboxArgs, 
		knockback_direction: Vector2
		) -> void :

	_hitbox.from = p_from
	spawn_position = pos
	velocity = p_velocity
	rotation = p_rotation

	_weapon_stats = p_weapon_stats
	_piercing = _weapon_stats.piercing
	_bounce = _weapon_stats.bounce
	_max_range = _weapon_stats.max_range

	_hitbox.damage_tracking_key_hash = damage_tracking_key
	set_effects(effects)
	_hitbox.set_damage(p_weapon_stats.damage, hitbox_args)
	_hitbox.set_knockback(knockback_direction, p_weapon_stats.knockback, p_weapon_stats.knockback_piercing)
	_hitbox.effect_scale = p_weapon_stats.effect_scale
	_hitbox.speed_percent_modifier = p_weapon_stats.speed_percent_modifier
	shoot()


func shoot() -> void :
	super.shoot()
	global_position = spawn_position
	_sprite.modulate.a = ProgressData.settings.projectile_opacity
	_set_time_until_max_range()


func _set_time_until_max_range() -> void :
	var add_dist = PROJECTILE_ADDITIONAL_DISTANCE
	if Utils.is_manual_aim(player_index):
		add_dist /= 2.0

	_time_until_max_range = (_max_range + add_dist) as float / _weapon_stats.projectile_speed


func set_effects(effects: Array) -> void :
	_hitbox.effects = effects

	_hitbox.projectiles_on_hit = []
	for effect in effects:

		if effect is ProjectilesOnHitEffect:
			if _hitbox.from is BuilderTurret:
				_hitbox.projectiles_on_hit = _hitbox.from.projectiles_on_hit
			else:
				_hitbox.projectiles_on_hit = _hitbox.from._hitbox.projectiles_on_hit
			break


func set_weapon_stats(p_weapon_stats: WeaponStats) -> void :
	_weapon_stats = p_weapon_stats
	_piercing = _weapon_stats.piercing
	_bounce = _weapon_stats.bounce
	_max_range = _weapon_stats.max_range


func _on_Hitbox_hit_something(thing_hit: Node, damage_dealt: int) -> void :
	emit_signal("hit_something", thing_hit, damage_dealt)
	RunData.manage_life_steal(_weapon_stats, _get_player_index())

	_hitbox.ignored_objects.append(thing_hit)

	if _bounce > 0:
		bounce(thing_hit)
	elif _piercing <= 0:
		stop()
	else:
		_piercing -= 1
		if _hitbox.damage > 0:
			_hitbox.damage = max(1, _hitbox.damage - (_hitbox.damage * _weapon_stats.piercing_dmg_reduction))


func bounce(thing_hit: Node) -> void :
	_bounce -= 1
	var target = thing_hit._entity_spawner_ref.get_rand_enemy(thing_hit)
	var direction = (target.global_position - global_position).angle() if target != null else randf_range( - PI, PI)
	velocity = Vector2.RIGHT.rotated(direction) * velocity.length()
	rotation = velocity.angle()
	_max_range = INFINITE_RANGE
	_set_time_until_max_range()
	set_knockback_vector(Vector2.ZERO, 0.0, 0.0)
	if _hitbox.damage > 0:
		_hitbox.damage = max(1, _hitbox.damage - (_hitbox.damage * _weapon_stats.bounce_dmg_reduction))


func _on_Hitbox_critically_hit_something(_thing_hit: Node, _damage_dealt: int) -> void :
	var remove_effects = []

	for effect in _hitbox.effects:
		if effect.key_hash == Keys.bounce_on_crit_hash:

			_bounce += 1
			effect.value -= 1

			if effect.value <= 0:
				remove_effects.push_back(effect)
		elif effect.key_hash == Keys.pierce_on_crit_hash:

			_piercing += 1
			effect.value -= 1

			if effect.value <= 0:
				remove_effects.push_back(effect)

	for effect in remove_effects:
		_hitbox.effects.erase(effect)

	emit_signal("critically_hit_something", _thing_hit, _damage_dealt)
