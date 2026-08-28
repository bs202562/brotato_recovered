class_name Ratzilla
extends Pet

onready var _hitbox: = $Hitbox as Hitbox
onready var _tween: = $Tween as Tween
var _current_cooldown: float = 0
var _is_shooting = false
var _base_weapon_stats: = WeaponStats.new()
var _current_weapon_stats: = WeaponStats.new()


func init(zone_min_pos: Vector2, zone_max_pos: Vector2, p_players_ref: Array = [], entity_spawner_ref = null) -> void :
	.init(zone_min_pos, zone_max_pos, p_players_ref, entity_spawner_ref)

	_hitbox.from = self

func update_data(effect: PetEffect) -> void :
	.update_data(effect)
	_base_weapon_stats = effect.weapon_stats

	reload_data()

	_current_cooldown = _current_weapon_stats.cooldown


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


func set_current_stats(stats: Array) -> void :
	_current_weapon_stats = stats[0]

	_hitbox.projectiles_on_hit = []
	_current_weapon_stats.burning_data.from = self

	var hitbox_args: = Hitbox.HitboxArgs.new().set_from_weapon_stats(_current_weapon_stats)
	_hitbox.effect_scale = _current_weapon_stats.effect_scale
	_hitbox.set_damage(_current_weapon_stats.damage, hitbox_args)
	_hitbox.speed_percent_modifier = _current_weapon_stats.speed_percent_modifier
	_hitbox.from = self


func get_stats() -> Array:
	return [_current_weapon_stats]

func _physics_process(delta: float) -> void :
	if not _is_shooting:
		_current_cooldown = max(_current_cooldown - Utils.physics_one(delta), 0)

	if _current_cooldown <= 0 and not _is_shooting:
		shoot()
	elif _current_cooldown <= 0 and _is_shooting:
		_hitbox.ignored_objects.clear()
		_hitbox.disable()
		_current_cooldown = _current_weapon_stats.cooldown
		_is_shooting = false

func shoot() -> void :
	_is_shooting = true
	_hitbox.enable()


func update_animation(movement: Vector2) -> void :
	.update_animation(movement)
	if movement.length() > 0.1:
		if not (_animation_player.current_animation == "move" or _animation_player.current_animation == "pet"):
			_animation_player.play("move")
	elif movement.length() <= 0.1:
		if not (_animation_player.current_animation == "idle_pet" or _animation_player.current_animation == "pet"):
			_animation_player.play("idle_pet")


func _on_Hitbox_hit_something(thing_hit, damage_dealt):
	RunData.manage_life_steal(_current_weapon_stats, player_index)

	if damage_dealt > 0:
		RunData.add_tracked_value(player_index, Keys.item_ratzilla_hash, damage_dealt, 1)

func _can_pet():
	if _check_can_be_pet():
		yield(get_tree().create_timer(0.1), "timeout")
		_animation_player.play("pet")
		yield(get_tree().create_timer(2.5), "timeout")
		_animation_player.play("idle_pet")

