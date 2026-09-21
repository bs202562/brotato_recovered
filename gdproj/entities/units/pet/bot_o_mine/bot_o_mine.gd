class_name BotOMine
extends Pet

export (String) var damage_tracking_id
export (AudioStream) var pet_sound

onready var _muzzle = $"%Muzzle"

var _targets_in_range: = []
var _current_target: = []

var _base_weapon_stats: = WeaponStats.new()
var _current_weapon_stats: = WeaponStats.new()
var _damage_tracking_id_hash: int = Keys.empty_hash
var _landmine_effect
var _cooldown: float = 0.0
var _landmines_cooldown: float = 0.0
var _is_shooting: bool = false
var _next_proj_rotation = 0

onready var _range_shape = $TargetTriggerZone / CollisionShape2D

func init(zone_min_pos: Vector2, zone_max_pos: Vector2, p_players_ref: Array = [], entity_spawner_ref = null) -> void :
	.init(zone_min_pos, zone_max_pos, p_players_ref, entity_spawner_ref)

	_movement_behavior._target_player = true
	_damage_tracking_id_hash = Keys.generate_hash(damage_tracking_id)

func update_data(effect: PetEffect) -> void :
	.update_data(effect)
	_landmine_effect = effect.landmine_effect_stat
	_base_weapon_stats = effect.weapon_stats

	reload_data()

	_cooldown = _current_weapon_stats.cooldown
	_landmines_cooldown = effect.landmine_effect_stat.spawn_cooldown

func should_data_be_reload() -> bool:
	return true

func reload_data():
	var args: = WeaponServiceInitStatsArgs.new()
	_current_weapon_stats = WeaponService.init_structure_pet_stats(_base_weapon_stats, player_index, args)
	if _range_shape:
		_range_shape.shape.radius = _current_weapon_stats.max_range
	_current_weapon_stats.burning_data.from = self

func set_current_stats(stats: Array) -> void :
	_current_weapon_stats = stats[0]
	if _range_shape:
		_range_shape.shape.radius = _current_weapon_stats.max_range
	_current_weapon_stats.burning_data.from = self

func get_stats() -> Array:
	return [_current_weapon_stats]

func _physics_process(delta) -> void :
	_cooldown = max(_cooldown - Utils.physics_one(delta), 0)
	_landmines_cooldown = max(_landmines_cooldown - Utils.physics_one(delta), 0)
	_current_target = Utils.get_nearest(_targets_in_range, global_position, _current_weapon_stats.min_range)

	if should_shoot():
		shoot()

	if should_spawn_landmines():
		spawn_landmines()

func should_shoot() -> bool:
	return (_cooldown == 0 and 
		not _is_shooting and 
		(
			_current_target.size() > 0
			and is_instance_valid(_current_target[0])
			and Utils.is_between(_current_target[1], _current_weapon_stats.min_range, _current_weapon_stats.max_range)
		)
	)

func shoot() -> void :
	if _current_target.size() == 0 or not is_instance_valid(_current_target[0]):
		_is_shooting = false
		_cooldown = _current_weapon_stats.cooldown
	else:
		var target_dir = (_current_target[0].global_position - global_position).angle()
		var accuracy_factor = rand_range( - 1 + _current_weapon_stats.accuracy, 1 - _current_weapon_stats.accuracy)
		_next_proj_rotation = target_dir + accuracy_factor

	var _projectile = _spawn_projectile(_animation.global_position + _muzzle.global_position - Vector2(100, 100))
	_is_shooting = false
	_cooldown = _current_weapon_stats.cooldown

func _spawn_projectile(position: Vector2) -> Array:
	var list_projectile: Array
	for i in _current_weapon_stats.nb_projectiles:
		var proj_rotation = rand_range(_next_proj_rotation - _current_weapon_stats.projectile_spread, _next_proj_rotation + _current_weapon_stats.projectile_spread)
		var args: = WeaponServiceSpawnProjectileArgs.new()
		args.knockback_direction = Vector2(cos(proj_rotation), sin(proj_rotation))
		args.from_player_index = player_index
		args.damage_tracking_key_hash = _damage_tracking_id_hash
		list_projectile.push_back(WeaponService.spawn_projectile(position, _current_weapon_stats, proj_rotation, self, args))
	return list_projectile

func should_spawn_landmines() -> bool:
	return _landmines_cooldown <= 0

func spawn_landmines() -> void :
	var pos = _entity_spawner_ref.get_spawn_pos_in_area(global_position, 100)
	var queue = _entity_spawner_ref.queues_to_spawn_structures[player_index]
	queue.push_back([EntityType.STRUCTURE, _landmine_effect.scene, pos, _landmine_effect])
	_landmines_cooldown = _landmine_effect.spawn_cooldown
	RunData.add_tracked_value(player_index, _damage_tracking_id_hash, 1, 1)

func _on_TargetTriggerZone_body_entered(body):
	_targets_in_range.push_back(body)
	var _error = body.connect("died", self, "on_target_died")

func _on_TargetTriggerZone_body_exited(body):
	_targets_in_range.erase(body)
	body.disconnect("died", self, "on_target_died")

func on_target_died(target: Node2D, _args: Entity.DieArgs) -> void :
	_targets_in_range.erase(target)


func update_animation(movement: Vector2) -> void :
	.update_animation(movement)
	if movement.length() > 0.1:
		if not (_animation_player.current_animation == "move" or _animation_player.current_animation == "pet"):
			_animation_player.play("move")
	elif movement.length() <= 0.1:
		if not (_animation_player.current_animation == "idle_pet" or _animation_player.current_animation == "pet"):
			_animation_player.play("idle_pet")


func _can_pet():
	if _check_can_be_pet():
		yield(get_tree().create_timer(0.1), "timeout")
		_animation_player.play("pet")
		SoundManager.play(pet_sound, 1, 0)
		yield(get_tree().create_timer(1.4), "timeout")
		_animation_player.play("idle_pet")
