class_name CatlingGun
extends Pet

@export var boosted_attack_speed_ratio: float = 0.5
@export var damage_tracking_id: String
@export var mad_sound: AudioStream
@export var purring_sound: AudioStream

@onready var _left_muzzle = $"%LeftMuzzle"
@onready var _right_muzzle = $"%RightMuzzle"
@onready var _gun_pivot_r = $"%Gun_pivot_r"
@onready var _gun_pivot_l = $"%Gun_pivot_l"

var _base_weapon_stats: = WeaponStats.new()
var _current_weapon_stats: = WeaponStats.new()

var close_player_array: = []
var _targets_in_range: = []
var _left_current_target: = []
var _right_current_target: = []

var _left_cooldown: float = 0.0
var _right_cooldown: float = 0.0
var _is_shooting: bool = false
var _next_proj_rotation = 0

var _damage_tracking_id_hash: int = Keys.empty_hash

func init(zone_min_pos: Vector2, zone_max_pos: Vector2, p_players_ref: Array = [], entity_spawner_ref = null) -> void :
	super.init(zone_min_pos, zone_max_pos, p_players_ref, entity_spawner_ref)

	_damage_tracking_id_hash = Keys.generate_hash(damage_tracking_id)

func update_data(effect: PetEffect) -> void :
	super.update_data(effect)

	_base_weapon_stats = effect.weapon_stats

	var args: = WeaponServiceInitStatsArgs.new()
	_current_weapon_stats = WeaponService.init_ranged_pet_stats(effect.weapon_stats, player_index, false, args)
	_current_weapon_stats.burning_data.from = self

	_left_cooldown = _current_weapon_stats.cooldown
	_right_cooldown = _current_weapon_stats.cooldown


func should_data_be_reload() -> bool:
	return true

func reload_data():
	var args: = WeaponServiceInitStatsArgs.new()
	_current_weapon_stats = WeaponService.init_ranged_pet_stats(_base_weapon_stats, player_index, false, args)
	_current_weapon_stats.burning_data.from = self

func set_current_stats(stats: Array) -> void :
	_current_weapon_stats = stats[0]
	_current_weapon_stats.burning_data.from = self

func get_stats() -> Array:
	return [_current_weapon_stats]

func _physics_process(delta) -> void :
	_catling_gun_physics_process_self(delta)
	super._physics_process(delta) # 4.x 移植: Godot 3 会自动调用父类，且子类的 return 不影响父类执行


# 4.x 移植: 原函数体抽出为独立方法，避免其中的 return 跳过父类调用
func _catling_gun_physics_process_self(delta) -> void :
	if dead: return

	_left_cooldown = max(_left_cooldown - Utils.physics_one(delta), 0)
	_right_cooldown = max(_right_cooldown - Utils.physics_one(delta), 0)
	_left_current_target = Utils.get_nearest(_targets_in_range, _animation.global_position + _left_muzzle.global_position - Vector2(100, 100), _current_weapon_stats.min_range)
	_right_current_target = Utils.get_nearest(_targets_in_range, _animation.global_position + _right_muzzle.global_position - Vector2(100, 100), _current_weapon_stats.min_range)

	_orient_gun(true)
	_orient_gun(false)

	if close_player_array.size() > 0 and _can_move:
		_can_move = false
		# 4.x 移植: 原 mode = MODE_STATIC，4.x 用 freeze + freeze_mode
		freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
		freeze = true
		is_boosted = true
		play_enter_in_mad_mode(true if close_player_array[0] is Player else false)
	elif close_player_array.size() == 0 and not _can_move:
		_can_move = true
		# 4.x 移植: 原 mode = MODE_CHARACTER(不旋转的刚体)，4.x 用解冻 + lock_rotation
		freeze = false
		lock_rotation = true
		_animation_player.play("idle_pet")
		is_boosted = false

	if should_shoot(_left_cooldown, _left_current_target):
		shoot(true, _left_current_target)
		_left_cooldown = _current_weapon_stats.cooldown
		_right_cooldown = _current_weapon_stats.cooldown / 2
		if is_boosted:
			_left_cooldown *= boosted_attack_speed_ratio
			_right_cooldown *= boosted_attack_speed_ratio
	elif should_shoot(_right_cooldown, _right_current_target):
		shoot(false, _right_current_target)
		_right_cooldown = _current_weapon_stats.cooldown
		_left_cooldown = _current_weapon_stats.cooldown / 2
		if is_boosted:
			_right_cooldown *= boosted_attack_speed_ratio
			_left_cooldown *= boosted_attack_speed_ratio

func play_enter_in_mad_mode(by_player: bool = false):
	SoundService.play_sound2d_with_limit("catling_gun_mad", mad_sound, 2, global_position, 0 if by_player else - 6.5, 0.1)
	_animation_player.play("enter_in_mad_mode")
	await _animation_player.animation_finished
	_animation_player.play("idle_attack")


func should_shoot(cooldown: float, current_target: Array) -> bool:
	return (cooldown == 0 and 
		not _is_shooting and 
		(
			current_target.size() > 0
			and is_instance_valid(current_target[0])
			and Utils.is_between(current_target[1], _current_weapon_stats.min_range, _current_weapon_stats.max_range)
		)
	)

func shoot(left: bool, current_target: Array) -> void :
	if sprite.scale.x < 0: left = not left
	var muzzle: Node2D = _left_muzzle if left else _right_muzzle
	var gun_pivot: Node2D = _gun_pivot_l if left else _gun_pivot_r

	if current_target.size() == 0 or not is_instance_valid(current_target[0]):
		_is_shooting = false
	else:
		var target_dir = (current_target[0].global_position - global_position).angle()
		var accuracy_factor = randf_range( - 1 + _current_weapon_stats.accuracy, 1 - _current_weapon_stats.accuracy)
		_next_proj_rotation = target_dir + accuracy_factor

	

	var _projectile = _spawn_projectile(_animation.global_position + muzzle.global_position - Vector2(100, 100))
	_is_shooting = false


func _orient_gun(left: bool):
	if sprite.scale.x < 0: left = not left
	var gun_pivot: Node2D = _gun_pivot_l if left else _gun_pivot_r
	if (left and _left_current_target.is_empty()) or ( not left and _right_current_target.is_empty()):
		return
	var target: Node2D = _left_current_target[0] if left else _right_current_target[0]

	var target_dir = (target.global_position - global_position).angle()
	var accuracy_factor = randf_range( - 1 + _current_weapon_stats.accuracy, 1 - _current_weapon_stats.accuracy)
	_next_proj_rotation = target_dir + accuracy_factor
	if sprite.scale.x > 0:
		gun_pivot.rotation_degrees = rad_to_deg(target_dir)
		if target.global_position.x > global_position.x:
			gun_pivot.scale.y = 1
		else:
			gun_pivot.scale.y = - 1
	else:
		gun_pivot.rotation_degrees = int(180 - rad_to_deg(target_dir)) % 360
		if target.global_position.x > global_position.x:
			gun_pivot.scale.y = - 1
		else:
			gun_pivot.scale.y = 1

	if (left and gun_pivot.scale.y > 0) or (( not left) and gun_pivot.scale.y < 0):
		gun_pivot.get_parent().move_child(gun_pivot, 4)
	else:
		gun_pivot.get_parent().move_child(gun_pivot, 1)

func _spawn_projectile(position: Vector2) -> Array:
	var list_projectile: Array
	for i in _current_weapon_stats.nb_projectiles:
		var proj_rotation = randf_range(_next_proj_rotation - _current_weapon_stats.projectile_spread, _next_proj_rotation + _current_weapon_stats.projectile_spread)
		var args: = WeaponServiceSpawnProjectileArgs.new()
		args.knockback_direction = Vector2(cos(proj_rotation), sin(proj_rotation))
		args.from_player_index = player_index
		args.damage_tracking_key_hash = _damage_tracking_id_hash
		list_projectile.push_back(WeaponService.spawn_projectile(position, _current_weapon_stats, proj_rotation, self, args))
	return list_projectile

func is_catling_gun() -> bool:
	return true

func _on_PlayerTriggerZone_body_entered(body):
	if body is Player or (body is Pet and not body.is_catling_gun()):
		if not close_player_array.has(body):
			close_player_array.push_back(body)


func _on_PlayerTriggerZone_body_exited(body):
	if body is Player or (body is Pet and not body.is_catling_gun()):
		close_player_array.erase(body)


func _on_TargetTriggerZone_body_entered(body):
	_targets_in_range.push_back(body)
	var _error = body.connect("died", Callable(self, "on_target_died"))


func _on_TargetTriggerZone_body_exited(body):
	_targets_in_range.erase(body)
	body.disconnect("died", Callable(self, "on_target_died"))

func on_target_died(target: Node2D, _args: Entity.DieArgs) -> void :
	_targets_in_range.erase(target)


func update_animation(movement: Vector2) -> void :
	super.update_animation(movement)
	if movement.length() > 0.1:
		if not (_animation_player.current_animation == "move" or _animation_player.current_animation == "idle_attack" or _animation_player.current_animation == "enter_in_mad_mode" or _animation_player.current_animation == "pet_the_cat"):
			_animation_player.play("move")
	elif movement.length() <= 0.1:
		if not (_animation_player.current_animation == "idle_pet" or _animation_player.current_animation == "idle_attack" or _animation_player.current_animation == "enter_in_mad_mode" or _animation_player.current_animation == "pet_the_cat"):
			_animation_player.play("idle_pet")


func _can_pet():
	_can_move = false
	# 4.x 移植: 原 mode = MODE_STATIC
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	freeze = true
	_animation_player.play("idle_pet")

	if _check_can_be_pet():
		await get_tree().create_timer(0.1).timeout
		_animation_player.play("pet_the_cat")
		SoundManager2D.play(purring_sound, global_position, 1, 0)
		await get_tree().create_timer(2).timeout
		_animation_player.play("idle_pet")
