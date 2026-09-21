class_name CharmEnemyEffectBehavior
extends EnemyEffectBehavior

export (int) var max_charm_count: = 5
export (int) var damage_increase: = 50
export (ShaderMaterial) var projectile_shader: = preload("res://resources/shaders/hue_shift_shadermat.tres")

onready var _charm_timer: Timer = $CharmTimer

var _absorb_next_damage: = false
var charmed: = false
var charmed_by_player_index: int
var _original_collision_layer: int
var _original_collision_mask: int
var _original_hitbox_layer: int
var _original_boost_mask: int
var _original_shooting_collision_layer: int
var _original_shooting_material: ShaderMaterial


func _ready():
	_charm_timer.wait_time = Utils.CHARM_DURATION


func should_add_on_spawn() -> bool:

	var player_has_charm_effect = false

	for player_data in RunData.players_data:
		if player_data.effects[Keys.charm_on_hit_hash].size() > 0:
			player_has_charm_effect = true
			break

	return player_has_charm_effect or RunData.existing_weapon_has_effect(Keys.charm_on_hit_hash)


func on_hurt(hitbox: Hitbox) -> void :
	if charmed or _parent.is_loot or _parent is Boss or not _parent.can_be_charmed or _parent.dead:
		return

	if hitbox and is_instance_valid(hitbox.from) and (hitbox.from is Enemy):
		return

	if not is_instance_valid(hitbox.from):
		return

	var from_player_index: int = hitbox.from.player_index
	if RunData.current_charmed_enemies[from_player_index] >= max_charm_count:
		return

	var charm_chance = 0.0
	for charm_effect in RunData.get_player_effect(Keys.charm_on_hit_hash, from_player_index):
		var hp_threshold_charmed = charm_effect[2] / 100.0
		if float(_parent.current_stats.health) / float(_parent.max_stats.health) < hp_threshold_charmed:
			assert (charm_effect[0] is int)
			var chance = max(1, (charm_effect[1] / 100.0) * Utils.get_stat(charm_effect[0], from_player_index))
			charm_chance += chance / 100.0

	for effect in hitbox.effects:
		if effect.custom_key_hash == Keys.charm_on_hit_hash:
			var hp_threshold_charmed = effect.value2 / 100.0
			if float(_parent.current_stats.health) / float(_parent.max_stats.health) < hp_threshold_charmed:
				charm_chance += effect.value / 100.0

	charm_chance = charm_chance / max(1.0, RunData.get_endless_factor() / 2.0)
	if not Utils.get_chance_success(charm_chance):
		return

	charm(from_player_index)


func charm(from_player_index: int) -> void :
	if charmed:
		return

	charmed_by_player_index = from_player_index
	charmed = true
	_absorb_next_damage = true
	RunData.current_charmed_enemies[from_player_index] += 1
	RunData.emit_signal("enemy_charmed", _parent)

	if not RunData.is_connected("enemy_charmed", _parent, "_on_enemy_charmed"):
		var _error_enemy_charmed = RunData.connect("enemy_charmed", _parent, "_on_enemy_charmed")

	_original_collision_layer = _parent.collision_layer
	_original_collision_mask = _parent.collision_mask
	_original_hitbox_layer = _parent._hitbox.collision_layer

	_parent.collision_layer = Utils.PETS_BIT
	_parent.collision_mask = Utils.PETS_BIT + Utils.OBSTACLES_BIT
	_parent._hurtbox.disable()
	_parent._hitbox.collision_layer = Utils.PET_PROJECTILES_BIT

	_parent.reset_damage_stat(damage_increase)

	for attack_behavior in _parent._all_attack_behaviors:
		if attack_behavior is ShootingAttackBehavior:
			_original_shooting_collision_layer = attack_behavior.custom_collision_layer
			_original_shooting_material = attack_behavior.custom_sprite_material

			attack_behavior.custom_collision_layer = Utils.PET_PROJECTILES_BIT
			var new_shader: = projectile_shader.duplicate()
			new_shader.set_shader_param("hue", Utils.CHARM_COLOR.h)
			attack_behavior.custom_sprite_material = new_shader

	if _parent is Healer or _parent is Buffer:
		_original_boost_mask = _parent._boost_zone.collision_mask
		_parent._boost_zone.collision_mask = Utils.PLAYER_BIT + Utils.STRUCTURES_BIT

	if _parent._movement_behavior is StayInRangeFromPlayerMovementBehavior or _parent._movement_behavior is FollowRandPosAroundPlayerMovementBehavior:
		var new_movement: = TargetRandPosMovementBehavior.new().init(_parent)
		_parent._current_movement_behavior = new_movement
		_parent.add_child(new_movement)

	if _parent.current_stats.speed > 0:
		_parent.bonus_speed += 100
	_parent.add_outline(Utils.CHARM_COLOR, 0.4, 0.75)
	_parent.update_target()
	_parent.shoot_animation_name = "shoot_charmed"
	_parent.sprite.self_modulate = Color.white

	_charm_timer.start()
	_parent.emit_signal("charmed", _parent)
	_parent.stop_burning()


func get_bonus_damage(_hitbox: Hitbox, _from_player_index: int) -> int:
	if _absorb_next_damage:
		_absorb_next_damage = false
		return 0 - Utils.LARGE_NUMBER
	return 0


func on_death(_die_args: Entity.DieArgs) -> void :
	if charmed:
		uncharm()


func update_target() -> void :
	if charmed:
		var min_dist_squared: int = Utils.LARGE_NUMBER
		for enemy in _parent._entity_spawner_ref.get_all_enemies():
			if enemy.collision_layer == Utils.ENEMIES_BIT and not enemy.dead and enemy.get_parent() != null:
				var dist_squared = _parent.global_position.distance_squared_to(enemy.global_position)
				if dist_squared < min_dist_squared:
					min_dist_squared = dist_squared
					_parent.current_target = enemy


func _on_CharmTimer_timeout() -> void :
	if _parent.dead or not is_instance_valid(_parent):
		return

	if not _parent.dead:
		_parent.die()


func uncharm() -> void :
	RunData.current_charmed_enemies[charmed_by_player_index] -= 1
	RunData.disconnect("enemy_charmed", _parent, "_on_enemy_charmed")

	_parent.collision_layer = _original_collision_layer
	_parent.collision_mask = _original_collision_mask
	_parent._hitbox.collision_layer = _original_hitbox_layer

	for attack_behavior in _parent._all_attack_behaviors:
		if attack_behavior is ShootingAttackBehavior:
			attack_behavior.custom_collision_layer = _original_shooting_collision_layer
			attack_behavior.custom_sprite_material = _original_shooting_material

	if _parent is Healer or _parent is Buffer:
		_parent._boost_zone.collision_mask = _original_boost_mask

	if _parent._movement_behavior is StayInRangeFromPlayerMovementBehavior or _parent._movement_behavior is FollowRandPosAroundPlayerMovementBehavior:
		_parent._current_movement_behavior.queue_free()
		_parent._current_movement_behavior = _parent._movement_behavior

	if _parent.current_stats.speed > 0:
		_parent.bonus_speed -= 100
	_parent.shoot_animation_name = "shoot"
