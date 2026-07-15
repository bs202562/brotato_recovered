class_name RangedWeaponShootingBehavior
extends WeaponShootingBehavior

signal projectile_shot(projectile)

var _ranged_spawn_projectile_args: = WeaponServiceSpawnProjectileArgs.new()


func shoot(_distance: float) -> void :
	SoundManager.play(Utils.get_rand_element(_parent.current_stats.shooting_sounds), _parent.current_stats.sound_db_mod, 0.2)

	var initial_position: Vector2 = _parent.sprite.position

	_parent.set_shooting(true)

	var attack_id: = _get_next_attack_id()
	for i in _parent.current_stats.nb_projectiles:
		var proj_rotation = randf_range(_parent.rotation - _parent.current_stats.projectile_spread, _parent.rotation + _parent.current_stats.projectile_spread)
		var projectile = shoot_projectile(proj_rotation, Vector2(cos(proj_rotation), sin(proj_rotation)))
		projectile._hitbox.player_attack_id = attack_id

	# 4.x 移植: 原武器上共享的 Tween 节点已移除，改用 create_tween()；
	# 后坐力(往后)与复位(回原位)两段依次播放，行为与原先一致
	var recoil_tween: = create_tween()
	recoil_tween.tween_property(
		_parent.sprite,
		"position",
		Vector2(initial_position.x - _parent.current_stats.recoil, initial_position.y),
		_parent.current_stats.recoil_duration
	).from(initial_position).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	await recoil_tween.finished

	var return_tween: = create_tween()
	return_tween.tween_property(
		_parent.sprite,
		"position",
		initial_position,
		_parent.current_stats.recoil_duration
	).from(_parent.sprite.position).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	await return_tween.finished

	_parent.set_shooting(false)


func shoot_projectile(rotation: float = _parent.rotation, knockback: Vector2 = Vector2.ZERO) -> Node:
	_ranged_spawn_projectile_args.knockback_direction = knockback
	_ranged_spawn_projectile_args.effects = _parent.effects
	_ranged_spawn_projectile_args.from_player_index = _parent.player_index

	var projectile = WeaponService.spawn_projectile(
		_parent.muzzle.global_position, 
		_parent.current_stats, 
		rotation, 
		_parent, 
		_ranged_spawn_projectile_args
	)

	emit_signal("projectile_shot", projectile)
	return projectile
