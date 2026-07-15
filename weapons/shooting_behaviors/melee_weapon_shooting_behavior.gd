class_name MeleeWeaponShootingBehavior
extends WeaponShootingBehavior

const MIN_SWEEP_DISTANCE = 250

var shooting_data: ShootingData

# 4.x 移植: 原先把多段 interpolate_property 排到武器上共享的 Tween 节点，
# 再 start() 一起并行播放。4.x 的 Tween 节点已移除，改为每一批 sample()
# 累积到一个 set_parallel(true) 的 create_tween()，由 _play_samples() 等待完成。
var _tween: Tween


func shoot(distance: float) -> void :
	var initial_position: Vector2 = _parent.sprite.position
	shooting_data = MeleeShootingData.new(_parent.current_stats, _parent.player_index)

	_parent.set_shooting(true)

	if _parent.next_attack_type == MeleeAttackType.THRUST:
		melee_thrust_attack(initial_position)
	else:
		melee_sweep_attack(initial_position, distance)


func sample(property: String, val_a, val_b, duration, tween_trans = Tween.TRANS_EXPO, tween_ease = Tween.EASE_OUT, object = _parent.sprite) -> void :
	if _tween == null or not _tween.is_valid():
		_tween = create_tween().set_parallel(true)
	_tween.tween_property(object, property, val_b, duration)\
		.from(val_a).set_trans(tween_trans).set_ease(tween_ease)


# 4.x 移植: 替代原来的 _parent.tween.start() + await tween_all_completed
func _play_samples() -> void :
	if _tween == null:
		return
	var tween: = _tween
	_tween = null
	if tween.is_valid():
		await tween.finished


func melee_sweep_attack(initial_position: Vector2, distance: float) -> void :
	_parent._hitbox.player_attack_id = _get_next_attack_id()

	var atk_distance = min(_parent.current_stats.max_range, max(MIN_SWEEP_DISTANCE, distance))

	shooting_data.update_atk_duration(atk_distance)

	var side_range = atk_distance / 2
	var recoil = _parent.current_stats.recoil
	var recoil_duration = _parent.current_stats.recoil_duration
	var sweep_angle = 0.9 * PI
	var sweep_half_duration = shooting_data.atk_duration / 4

	var side_a = side_range
	var side_b = - side_range
	var angle_a = sweep_angle
	var angle_b = - sweep_angle

	if not _parent.sprite.flip_v:
		side_a = - side_range
		side_b = side_range
		angle_a = - sweep_angle
		angle_b = sweep_angle

	sample("position", initial_position, Vector2(initial_position.x - recoil, initial_position.y + side_a), recoil_duration)
	sample("rotation", _parent.sprite.rotation, angle_a, recoil_duration)

	await _play_samples()

	SoundManager.play(Utils.get_rand_element(_parent.current_stats.shooting_sounds), _parent.current_stats.sound_db_mod, 0.2)
	_parent.enable_hitbox()

	sample("position", _parent.sprite.position, Vector2(initial_position.x + _parent.get_sweep_range(atk_distance) * 0.75, initial_position.y), sweep_half_duration, Tween.TRANS_LINEAR)
	sample("rotation", _parent.sprite.rotation, 0, sweep_half_duration, Tween.TRANS_LINEAR)

	await _play_samples()

	sample("position", _parent.sprite.position, Vector2(initial_position.x - recoil, initial_position.y + side_b), sweep_half_duration, Tween.TRANS_LINEAR)
	sample("rotation", _parent.sprite.rotation, angle_b, sweep_half_duration, Tween.TRANS_LINEAR)

	await _play_samples()

	if not _parent.stats.deal_dmg_on_return:
		_parent.disable_hitbox()

	sample("position", _parent.sprite.position, initial_position, shooting_data.back_duration)
	sample("rotation", _parent.sprite.rotation, 0, shooting_data.back_duration)

	await _play_samples()

	if _parent.stats.deal_dmg_on_return:
		_parent.disable_hitbox()

	_parent.set_shooting(false)


func melee_thrust_attack(initial_position: Vector2) -> void :
	_parent._hitbox.player_attack_id = _get_next_attack_id()

	var recoil = _parent.current_stats.recoil
	var recoil_duration = _parent.current_stats.recoil_duration
	var thrust_half_duration = shooting_data.atk_duration / 2

	sample("position", initial_position, Vector2(initial_position.x - recoil, initial_position.y), recoil_duration)

	await _play_samples()

	SoundManager.play(Utils.get_rand_element(_parent.current_stats.shooting_sounds), _parent.current_stats.sound_db_mod, 0.2)
	_parent.enable_hitbox()

	sample("position", _parent.sprite.position, Vector2(initial_position.x + _parent.current_stats.max_range, initial_position.y), thrust_half_duration)

	await _play_samples()

	if not _parent.stats.deal_dmg_on_return:
		_parent.disable_hitbox()

	sample("position", _parent.sprite.position, initial_position, shooting_data.back_duration)

	await _play_samples()

	if _parent.stats.deal_dmg_on_return:
		_parent.disable_hitbox()

	_parent.set_shooting(false)
