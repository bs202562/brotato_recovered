class_name Blazemander
extends Pet

@onready var _hitbox: = $Hitbox as Hitbox
var _current_cooldown: float = 0
var _current_ranged_cooldown: float = 0
var _base_weapon_stats: = WeaponStats.new()
var _base_ranged_weapon_stats: = WeaponStats.new()
var _base_burning_data: = BurningData.new()
var _current_weapon_stats: = WeaponStats.new()
var _current_ranged_weapon_stats: = RangedWeaponStats.new()
var _current_burning_data: = BurningData.new()
var _is_attacking = false
var _is_firing = false
var _enemies_inside_zone = 0

func init(zone_min_pos: Vector2, zone_max_pos: Vector2, p_players_ref: Array = [], entity_spawner_ref = null) -> void :
	super.init(zone_min_pos, zone_max_pos, p_players_ref, entity_spawner_ref)

	_hitbox.from = self

func update_data(effect: PetEffect) -> void :
	super.update_data(effect)
	_base_weapon_stats = effect.weapon_stats
	_base_ranged_weapon_stats = effect.ranged_weapon_stats
	_base_burning_data = effect.burning_data

	reload_data()

	_current_cooldown = _current_weapon_stats.cooldown
	_current_ranged_cooldown = randf_range(_current_ranged_weapon_stats.cooldown / 4, _current_ranged_weapon_stats.cooldown)

func should_data_be_reload() -> bool:
	return true

func reload_data():
	var args: = WeaponServiceInitStatsArgs.new()
	_current_weapon_stats = WeaponService.init_melee_pet_stats(_base_weapon_stats, player_index, args)
	_current_ranged_weapon_stats = WeaponService.init_ranged_pet_stats(_base_ranged_weapon_stats, player_index, false, args)
	_current_burning_data = WeaponService.init_burning_data(_base_burning_data, player_index, false, true)

	_hitbox.projectiles_on_hit = []

	_current_weapon_stats.burning_data.chance = _current_burning_data.chance
	_current_weapon_stats.burning_data.damage = _current_burning_data.damage
	_current_weapon_stats.burning_data.duration = _current_burning_data.duration
	_current_weapon_stats.burning_data.spread = _current_burning_data.spread
	_current_weapon_stats.burning_data.scaling_stats.clear()
	for stat in _current_burning_data.scaling_stats:
		_current_weapon_stats.burning_data.scaling_stats.push_back(stat)
	_current_weapon_stats.burning_data.is_global_burn = _current_burning_data.is_global_burn

	_current_weapon_stats.burning_data.from = self

	_current_ranged_weapon_stats.burning_data.chance = _current_burning_data.chance
	_current_ranged_weapon_stats.burning_data.damage = _current_burning_data.damage
	_current_ranged_weapon_stats.burning_data.duration = _current_burning_data.duration
	_current_ranged_weapon_stats.burning_data.spread = _current_burning_data.spread
	_current_ranged_weapon_stats.burning_data.scaling_stats.clear()
	for stat in _current_burning_data.scaling_stats:
		_current_ranged_weapon_stats.burning_data.scaling_stats.push_back(stat)
	_current_ranged_weapon_stats.burning_data.is_global_burn = _current_burning_data.is_global_burn

	_current_ranged_weapon_stats.burning_data.from = self

	var hitbox_args: = Hitbox.HitboxArgs.new().set_from_weapon_stats(_current_weapon_stats)

	_hitbox.effect_scale = _current_weapon_stats.effect_scale
	_hitbox.set_damage(_current_weapon_stats.damage, hitbox_args)
	_hitbox.speed_percent_modifier = _current_weapon_stats.speed_percent_modifier
	_hitbox.from = self

func set_current_stats(stats: Array) -> void :
	_current_weapon_stats = stats[0]
	_current_ranged_weapon_stats = stats[1]
	_current_burning_data = stats[2]

	_hitbox.projectiles_on_hit = []

	_current_weapon_stats.burning_data.chance = _current_burning_data.chance
	_current_weapon_stats.burning_data.damage = _current_burning_data.damage
	_current_weapon_stats.burning_data.duration = _current_burning_data.duration
	_current_weapon_stats.burning_data.spread = _current_burning_data.spread
	_current_weapon_stats.burning_data.scaling_stats.clear()
	for stat in _current_burning_data.scaling_stats:
		_current_weapon_stats.burning_data.scaling_stats.push_back(stat)
	_current_weapon_stats.burning_data.is_global_burn = _current_burning_data.is_global_burn

	_current_weapon_stats.burning_data.from = self

	_current_ranged_weapon_stats.burning_data.chance = _current_burning_data.chance
	_current_ranged_weapon_stats.burning_data.damage = _current_burning_data.damage
	_current_ranged_weapon_stats.burning_data.duration = _current_burning_data.duration
	_current_ranged_weapon_stats.burning_data.spread = _current_burning_data.spread
	_current_ranged_weapon_stats.burning_data.scaling_stats.clear()
	for stat in _current_burning_data.scaling_stats:
		_current_ranged_weapon_stats.burning_data.scaling_stats.push_back(stat)
	_current_ranged_weapon_stats.burning_data.is_global_burn = _current_burning_data.is_global_burn

	_current_ranged_weapon_stats.burning_data.from = self

	var hitbox_args: = Hitbox.HitboxArgs.new().set_from_weapon_stats(_current_weapon_stats)

	_hitbox.effect_scale = _current_weapon_stats.effect_scale
	_hitbox.set_damage(_current_weapon_stats.damage, hitbox_args)
	_hitbox.speed_percent_modifier = _current_weapon_stats.speed_percent_modifier
	_hitbox.from = self

func get_stats() -> Array:
	return [_current_weapon_stats, _current_ranged_weapon_stats, _current_burning_data]

func _physics_process(delta: float) -> void :
	if _current_target_behavior.should_update_target():
		_current_target_behavior.update_target()

	if not _is_attacking:
		_current_cooldown = max(_current_cooldown - Utils.physics_one(delta), 0)
		_current_ranged_cooldown = max(_current_ranged_cooldown - Utils.physics_one(delta), 0)

	if _current_ranged_cooldown <= 0 and not _is_firing and not _is_attacking:
		if _enemies_inside_zone > 0:
			_is_firing = true
			shot_circle_of_fire(6)
	elif _current_cooldown <= 0 and not _is_attacking and not _is_firing:
		if _enemies_inside_zone > 0:
			attack()
	elif _current_ranged_cooldown == 0 and _is_firing:
		_is_firing = false
		_current_ranged_cooldown = _current_ranged_weapon_stats.cooldown
	elif _current_cooldown == 0 and _is_attacking:
		_hitbox.ignored_objects.clear()
		_hitbox.disable()
		_current_cooldown = _current_weapon_stats.cooldown
		_is_attacking = false

	super._physics_process(delta) # 4.x 移植: Godot 3 自动调用父类虚函数，4.x 需显式调用（_physics_process 为子类优先）

func shot_circle_of_fire(n: int) -> void :
	for i in range(n):
		_spawn_projectile(global_position, (2 * PI / n) * i)

func _spawn_projectile(position: Vector2, proj_rotation: float) -> Node:
	var next_proj_rotation = randf_range(proj_rotation - _current_ranged_weapon_stats.projectile_spread, proj_rotation + _current_ranged_weapon_stats.projectile_spread)
	var args: = WeaponServiceSpawnProjectileArgs.new()
	args.knockback_direction = Vector2(cos(proj_rotation), sin(proj_rotation))
	args.from_player_index = player_index
	args.damage_tracking_key_hash = Keys.item_blazemander_hash
	return WeaponService.spawn_projectile(position, _current_ranged_weapon_stats, next_proj_rotation, self, args)

func attack() -> void :
	_animation_player.play("attack")
	_is_attacking = true
	await get_tree().create_timer(0.15).timeout
	_hitbox.enable()


func update_animation(movement: Vector2) -> void :
	super.update_animation(movement)
	if movement.length() > 0.1:
		if not (_animation_player.current_animation == "move" or _animation_player.current_animation == "attack" or _animation_player.current_animation == "pet"):
			_animation_player.play("move")
	elif movement.length() <= 0.1:
		if not (_animation_player.current_animation == "idle_pet" or _animation_player.current_animation == "attack" or _animation_player.current_animation == "pet"):
			_animation_player.play("idle_pet")

func on_weapon_hit_something(_thing_hit: Node, damage_dealt: int, hitbox: Hitbox) -> void :
	RunData.add_tracked_value(player_index, Keys.item_blazemander_hash, damage_dealt)

func _on_Hitbox_hit_something(thing_hit, damage_dealt):
	RunData.manage_life_steal(_current_weapon_stats, player_index)

	if damage_dealt > 0:
		RunData.add_tracked_value(player_index, Keys.item_blazemander_hash, damage_dealt)


func _on_Enemy_detection_body_entered(_body):
	_enemies_inside_zone += 1


func _on_Enemy_detection_body_exited(_body):
	_enemies_inside_zone -= 1


func _can_pet():
	if _check_can_be_pet():
		await get_tree().create_timer(0.1).timeout
		_animation_player.play("pet")
		await get_tree().create_timer(1).timeout
		_animation_player.play("idle_pet")
