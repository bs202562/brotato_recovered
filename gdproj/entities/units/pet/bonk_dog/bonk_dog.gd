class_name BonkDog
extends Pet

export (float) var charge_duration = 0.5
export (float) var min_squared_distance_for_jump_attack = 250
export (Array, Resource) var sound_attack

onready var _hitbox: = $Hitbox as Hitbox
onready var _tween: = $Tween as Tween
onready var _audio_stream_player: = $"%AudioStreamPlayer2D" as AudioStreamPlayer2D
var _current_cooldown: float = 0
var _is_shooting = false
var _is_jumping = false
var _explosion_effect = null
var _base_weapon_stats: = WeaponStats.new()
var _base_explosion_weapon_stats: = WeaponStats.new()
var _current_weapon_stats: = WeaponStats.new()
var _current_explosion_weapon_stats: = WeaponStats.new()
var _explosion_args: = WeaponServiceExplodeArgs.new()

var _current_ultime_cooldown: float = 0


func init(zone_min_pos: Vector2, zone_max_pos: Vector2, p_players_ref: Array = [], entity_spawner_ref = null) -> void :
	.init(zone_min_pos, zone_max_pos, p_players_ref, entity_spawner_ref)

	_hitbox.from = self

func update_data(effect: PetEffect) -> void :
	.update_data(effect)
	_explosion_effect = effect.explosion_effect
	_base_weapon_stats = effect.weapon_stats
	_base_explosion_weapon_stats = effect.explosion_effect.stats as WeaponStats

	reload_data()

	_current_cooldown = _current_weapon_stats.cooldown
	_current_ultime_cooldown = rand_range(effect.explosion_effect.stats.cooldown / 4, effect.explosion_effect.stats.cooldown)

func should_data_be_reload() -> bool:
	return true

func reload_data():
	var args: = WeaponServiceInitStatsArgs.new()
	_current_weapon_stats = WeaponService.init_melee_pet_stats(_base_weapon_stats, player_index, args)
	_hitbox.projectiles_on_hit = []
	_current_weapon_stats.burning_data.from = self

	var hitbox_args: = Hitbox.HitboxArgs.new().set_from_weapon_stats(_current_weapon_stats)
	_hitbox.effect_scale = _current_weapon_stats.effect_scale
	_hitbox.set_damage(_current_weapon_stats.damage, hitbox_args)
	_hitbox.speed_percent_modifier = _current_weapon_stats.speed_percent_modifier
	_hitbox.from = self

	var stats_explosion_args: = WeaponServiceInitStatsArgs.new()
	stats_explosion_args.effects.push_back(_explosion_effect)
	_current_explosion_weapon_stats = WeaponService.init_base_stats(_base_explosion_weapon_stats, player_index, stats_explosion_args, false, false, true)
	_explosion_args.damage = _current_explosion_weapon_stats.damage
	_explosion_args.accuracy = _current_explosion_weapon_stats.accuracy
	_explosion_args.crit_chance = _current_explosion_weapon_stats.crit_chance
	_explosion_args.crit_damage = _current_explosion_weapon_stats.crit_damage
	_explosion_args.burning_data = _current_explosion_weapon_stats.burning_data
	_explosion_args.scaling_stats = _current_explosion_weapon_stats.scaling_stats
	_explosion_args.from_player_index = player_index
	_explosion_args.damage_tracking_key_hash = Keys.generate_hash(_explosion_effect.tracking_key)
	_explosion_args.from = self

func set_current_stats(stats: Array) -> void :
	_current_weapon_stats = stats[0]
	_current_explosion_weapon_stats = stats[1]

	_hitbox.projectiles_on_hit = []
	_current_weapon_stats.burning_data.from = self

	var hitbox_args: = Hitbox.HitboxArgs.new().set_from_weapon_stats(_current_weapon_stats)
	_hitbox.effect_scale = _current_weapon_stats.effect_scale
	_hitbox.set_damage(_current_weapon_stats.damage, hitbox_args)
	_hitbox.speed_percent_modifier = _current_weapon_stats.speed_percent_modifier
	_hitbox.from = self

	_explosion_args.damage = _current_explosion_weapon_stats.damage
	_explosion_args.accuracy = _current_explosion_weapon_stats.accuracy
	_explosion_args.crit_chance = _current_explosion_weapon_stats.crit_chance
	_explosion_args.crit_damage = _current_explosion_weapon_stats.crit_damage
	_explosion_args.burning_data = _current_explosion_weapon_stats.burning_data
	_explosion_args.scaling_stats = _current_explosion_weapon_stats.scaling_stats
	_explosion_args.from_player_index = player_index
	_explosion_args.damage_tracking_key_hash = Keys.generate_hash(_explosion_effect.tracking_key)
	_explosion_args.from = self

func get_stats() -> Array:
	return [_current_weapon_stats, _current_explosion_weapon_stats]

func _physics_process(delta: float) -> void :
	if not _is_shooting:
		_current_cooldown = max(_current_cooldown - Utils.physics_one(delta), 0)
		_current_ultime_cooldown = max(_current_ultime_cooldown - Utils.physics_one(delta), 0)

	if _current_ultime_cooldown <= 0 and not _is_jumping and not _is_shooting and can_jump():
		jump()
	elif _current_cooldown <= 0 and not _is_shooting and not _is_jumping:
		shoot()
	elif _current_cooldown == 0 and _is_shooting:
		_hitbox.ignored_objects.clear()
		_hitbox.disable()
		_current_cooldown = _current_weapon_stats.cooldown
		_is_shooting = false

func shoot() -> void :
	_is_shooting = true
	_hitbox.enable()

func can_jump() -> bool:
	return _entity_spawner_ref.get_all_enemies(false).size() > 0 and RunData.wave_in_progress

func jump() -> void :
	if dead or _animation_player.current_animation == "pet_the_dog":
		return
	
	var enemies_list = _entity_spawner_ref.get_all_enemies(false)
	var max_life: = - 1
	var target_enemy = null
	for enemy in enemies_list:
		if global_position.distance_squared_to(enemy.global_position) > min_squared_distance_for_jump_attack:
			if enemy.max_stats.health > max_life:
				max_life = enemy.max_stats.health
				target_enemy = enemy

	if target_enemy == null:
		_current_ultime_cooldown = _explosion_effect.stats.cooldown * 0.4
		return

	_is_jumping = true
	_move_locked = true
	_animation_player.play("attack")
	SoundService.play_sound2d_with_limit("bonk_dog_attack", sound_attack.pick_random(), 1, global_position)

	
	_tween.interpolate_property(self, "global_position", global_position, target_enemy.global_position, charge_duration, 5)
	_tween.interpolate_callback(self, charge_duration, "jump_landing")
	_tween.start()
	

func jump_landing() -> void :
	_is_jumping = false
	_move_locked = false
	_current_ultime_cooldown = _explosion_effect.stats.cooldown
	_explosion_args.pos = global_position
	var _inst = WeaponService.explode(_explosion_effect, _explosion_args)
	_current_target_behavior.update_target()


func update_animation(movement: Vector2) -> void :
	.update_animation(movement)
	if movement.length() > 0.1:
		if not (_animation_player.current_animation == "move" or _animation_player.current_animation == "attack" or _animation_player.current_animation == "pet_the_dog"):
			_animation_player.play("move")
	elif movement.length() <= 0.1:
		if not (_animation_player.current_animation == "idle_dog" or _animation_player.current_animation == "attack" or _animation_player.current_animation == "pet_the_dog"):
			_animation_player.play("idle_dog")


func _on_Hitbox_hit_something(thing_hit, damage_dealt):
	RunData.manage_life_steal(_current_weapon_stats, player_index)

	if damage_dealt > 0:
		RunData.add_tracked_value(player_index, Keys.item_bonk_dog_hash, damage_dealt, 1)

func _can_pet():
	if _check_can_be_pet():
		yield(get_tree().create_timer(0.1), "timeout")
		_animation_player.play("pet_the_dog")
		yield(get_tree().create_timer(2.5), "timeout")
		_animation_player.play("idle_dog")
