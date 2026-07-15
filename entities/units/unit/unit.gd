class_name Unit
extends Entity

signal speed_removed(enemy)
signal health_updated(unit, current_health, max_health)
signal took_damage(unit, value, knockback_direction, is_crit, is_dodge, is_protected, armor_did_something, args, hit_type, is_one_shot)
signal crit_effect(weapon)
signal one_shot_effect(unit)

@export var crit_sounds: Array = [] # (Array, Resource)
@export var hurt_sounds: Array = [] # (Array, Resource)
@export var burn_sounds: Array = [] # (Array, Resource)
@export var dodge_sounds: Array = [] # (Array, Resource)
@export var stats: Resource
@export var mirror_sprite_with_movement: bool = true
@export var flash_mat: Resource


const THRESHOLD_DIST_TO_LOWER_DMG_ON_PULL: = 200
const MIN_DEATH_KNOCKBACK_AMOUNT: = 15.0

var current_stats: LiveStats = LiveStats.new()
var max_stats: LiveStats = LiveStats.new()

var can_drop_loot: = true
var bonus_speed: int = 0
var knockback_vector: = Vector2.ZERO

var _speed_percent_modifier: = 0
var _speed_rand_value: = 0
var _hitbox_damage_modifier: = 0

var players_ref: = []
var _entity_spawner_ref: EntitySpawner
var _can_move: bool = true
var _current_movement: = Vector2.ZERO
var _move_locked: = false
var decaying_bonus_speed: = 0.0
var _non_flash_material: ShaderMaterial = null

var burning_particles = null
var _burning: BurningData
var _burning_player_index: int = - 1
var _is_burning: bool = false
var _explode_args_unit: = WeaponServiceExplodeArgs.new()

var _current_movement_behavior: MovementBehavior
var _die_args_unit: = Entity.DieArgs.new()
var _spawn_projectile_args = WeaponServiceSpawnProjectileArgs.new()
var _take_damage_args_unit: = TakeDamageArgs.new(0)

@onready var effect_behaviors: = $EffectBehaviors
@onready var _flash_timer: = $FlashTimer as Timer
@onready var _hurtbox: = $Hurtbox as Area2D
@onready var _movement_behavior: = $MovementBehavior
@onready var _burning_timer: = $BurningTimer as Timer
@onready var _burning_particles: = $BurningParticles


func _ready() -> void :
	_current_movement_behavior = _movement_behavior


func init(zone_min_pos: Vector2, zone_max_pos: Vector2, p_players_ref: Array = [], entity_spawner_ref = null) -> void :
	super.init(zone_min_pos, zone_max_pos)

	var burning_cooldown_reduction = RunData.sum_all_player_effects(Keys.burning_cooldown_reduction_hash) / 100.0
	var burning_cooldown_increase = RunData.sum_all_player_effects(Keys.burning_cooldown_increase_hash) / 100.0
	var burning_cooldown_diff = burning_cooldown_increase - burning_cooldown_reduction

	_burning_timer.wait_time = max(0.1, _burning_timer.wait_time * (1.0 + burning_cooldown_diff))

	players_ref = p_players_ref
	_entity_spawner_ref = entity_spawner_ref

	_movement_behavior.init(self)
	_speed_rand_value = randf_range( - stats.speed_randomization * RunData.current_run_accessibility_settings.speed, stats.speed_randomization * RunData.current_run_accessibility_settings.speed) as int


func respawn() -> void :
	super.respawn()
	knockback_vector = Vector2.ZERO
	_can_move = true
	can_drop_loot = true
	bonus_speed = 0
	_hurtbox.enable()
	_current_movement_behavior = _movement_behavior
	_speed_rand_value = randf_range( - stats.speed_randomization * RunData.current_run_accessibility_settings.speed, stats.speed_randomization * RunData.current_run_accessibility_settings.speed) as int


func init_current_stats() -> void :
	max_stats.copy_stats(stats)
	current_stats.copy(max_stats)
	reset_health_stat(0)
	reset_damage_stat(0)
	reset_speed_stat(0)
	reset_armor_stat(0)

func get_stats_value() -> int:
	return stats.value

func reset_health_stat(percent_modifier: int = 0) -> void :
	current_stats.health = EntityService.get_final_enemy_health(stats.get_base_health(RunData.current_wave), percent_modifier)
	max_stats.health = current_stats.health


func reset_damage_stat(percent_modifier: int = 0) -> void :
	current_stats.damage = EntityService.get_final_enemy_damage(stats.get_base_damage(RunData.current_wave), percent_modifier)
	max_stats.damage = current_stats.damage


func reset_speed_stat(percent_modifier: int = 0) -> void :
	_speed_percent_modifier = percent_modifier

	var effect_modifiers: = 1.0
	for player_index in RunData.get_player_count():
		effect_modifiers *= 1.0 + get_speed_effect_mods(player_index) / 100.0

	current_stats.speed = EntityService.get_final_enemy_speed(stats.speed + _speed_rand_value, effect_modifiers, percent_modifier)
	max_stats.speed = current_stats.speed


func get_speed_effect_mods(player_index: int) -> int:
	var enemy_speed = Utils.get_stat(Keys.enemy_speed_hash, player_index)
	var speed_from_burn = RunData.get_player_effect(Keys.burning_enemy_speed_hash, player_index) if _is_burning else 0
	return enemy_speed + speed_from_burn


func reset_armor_stat(percent_modifier: = 0) -> void :
	var base_armor = (stats.armor + (stats.armor_increase_each_wave * (RunData.current_wave - 1))) * (1.0 + percent_modifier / 100.0)
	current_stats.armor = round(base_armor) as int
	max_stats.armor = current_stats.armor


var _integrate_forces_velocity: Vector2
func _physics_process(delta: float) -> void :
	_current_movement = get_movement() if _can_move else Vector2.ZERO
	update_animation(_current_movement)

	var velocity = get_next_velocity()
	_integrate_forces_velocity = velocity
	# 4.x 移植: 3.x 的 mode==MODE_KINEMATIC 对应 4.x 的 freeze + FREEZE_MODE_KINEMATIC；
	# RigidBody2D.test_motion() 已移除，改用 PhysicsServer2D.body_test_motion()
	if freeze and freeze_mode == FREEZE_MODE_KINEMATIC:

		var margin = 0.08
		var delta_position: = Vector2.ZERO
		var result = PhysicsTestMotionResult2D.new()
		var params = PhysicsTestMotionParameters2D.new()
		params.from = global_transform
		params.motion = velocity * delta
		params.margin = margin
		var is_colliding = PhysicsServer2D.body_test_motion(get_rid(), params, result)
		global_position += result.get_travel()
		delta_position += result.get_travel()
		if is_colliding:
			var slide_velocity = velocity.slide(result.get_collision_normal())
			params.from = global_transform
			params.motion = slide_velocity * delta
			var _is_colliding = PhysicsServer2D.body_test_motion(get_rid(), params, result)
			global_position += result.get_travel()
			delta_position += result.get_travel()
		_on_moved(delta_position)

	if decaying_bonus_speed > 0:
		decaying_bonus_speed = max(decaying_bonus_speed - 60 * delta, 0.0)
	elif decaying_bonus_speed < 0:
		decaying_bonus_speed = min(decaying_bonus_speed + 60 * delta * 5, 0.0)


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void :
	if sleeping:
		return

	if freeze and freeze_mode == FREEZE_MODE_KINEMATIC: # 4.x 移植: 原 mode == MODE_KINEMATIC

		state.transform.origin = global_position
		return
	
	
	var target_position = _current_movement_behavior.get_target_position()

	
	var next_position = state.transform.origin + _integrate_forces_velocity * state.step
	var zone_rect = ZoneService.get_current_zone_rect()
	if not zone_rect.has_point(next_position):
		next_position.x = clamp(next_position.x, zone_rect.position.x, zone_rect.end.x)
		next_position.y = clamp(next_position.y, zone_rect.position.y, zone_rect.end.y)

		var new_velocity = (next_position - state.transform.origin) / state.step
		_integrate_forces_velocity = new_velocity

	
	if (
		target_position == null
		or _integrate_forces_velocity == Vector2.ZERO
		or not _can_move
		or _move_locked
	):
		state.linear_velocity = _integrate_forces_velocity
		return
	var origin_to_next_origin = _integrate_forces_velocity * state.step
	var origin_to_target = target_position - state.transform.origin
	
	if origin_to_target.length_squared() > origin_to_next_origin.length_squared():
		state.linear_velocity = _integrate_forces_velocity
		return
	
	
	var projected_target = state.transform.origin + origin_to_target.project(origin_to_next_origin)
	
	
	
	if ((state.transform.origin + origin_to_next_origin) - projected_target).dot(state.transform.origin - projected_target) <= 0:
		state.linear_velocity = Vector2.ZERO
		state.transform.origin = target_position
		return
	state.linear_velocity = _integrate_forces_velocity


func get_movement() -> Vector2:
	return _current_movement_behavior.get_movement() if not _move_locked else _current_movement


func get_move_input() -> Vector2:
	return _current_movement.normalized() * get_move_speed()


func get_move_speed() -> float:
	return max(0.0, (current_stats.speed + bonus_speed + decaying_bonus_speed))


func get_next_velocity() -> Vector2:
	return get_move_input() + get_next_knockback_value()


func get_next_knockback_value() -> Vector2:
	if knockback_vector.length_squared() == 0:
		return Vector2.ZERO

	knockback_vector = knockback_vector.lerp(Vector2.ZERO, 0.1)
	return get_knockback_value()


func get_knockback_value() -> Vector2:
	return (knockback_vector * (100 - (stats.knockback_resistance * 100)))


func get_direction() -> int:
	return sprite.scale.x as int


func get_current_target() -> Vector2:
	return _current_movement_behavior.get_target_position()


func update_animation(movement: Vector2) -> void :
	if mirror_sprite_with_movement:
		if movement.x > 0:
			sprite.scale.x = abs(sprite.scale.x)
		elif movement.x < 0:
			sprite.scale.x = - abs(sprite.scale.x)


func _get_movement() -> Vector2:
	return Vector2.ZERO


func take_damage(value: int, args: TakeDamageArgs) -> Array:
	if _pending_die:
		return [0, 0, false]

	var hitbox = args.hitbox
	var from_player_index = args.from_player_index

	var crit_damage = 0.0
	var crit_chance = 0.0
	var knockback_direction = Vector2.ZERO
	var knockback_amount = 0.0
	var knockback_piercing = 0.0
	var dmg_taken = [0, 0, false]

	if hitbox != null:
		crit_damage = hitbox.crit_damage
		crit_chance = hitbox.crit_chance
		knockback_direction = hitbox.knockback_direction
		if from_player_index < players_ref.size() and is_instance_valid(players_ref[from_player_index]):
			knockback_direction = 0.2 * knockback_direction + 0.8 * players_ref[from_player_index].global_position.direction_to(global_position)
		knockback_amount = hitbox.knockback_amount
		knockback_piercing = hitbox.knockback_piercing

	var is_crit = true if Utils.get_chance_success(crit_chance) else false
	var is_one_shot = false
	if hitbox:
		for effect in hitbox.effects:
			if _is_burning and effect.key_hash == Keys.crit_on_hitting_burning_target_hash:
				is_crit = true
			elif effect is OneShotOnHitEffect:
				if Utils.get_chance_success(effect.value / 100.0):
					is_one_shot = true
					_on_one_shotted(effect)
				else: is_one_shot = false

	var dmg_value = value
	var sound = Utils.get_rand_element(hurt_sounds)
	if is_crit:
		dmg_value = round(value * crit_damage) as int
		sound = Utils.get_rand_element(crit_sounds)

	var dmg_value_result = get_damage_value(dmg_value, from_player_index, args.armor_applied, args.dodgeable, is_crit, hitbox, args.is_burning)
	if is_one_shot:
		dmg_value_result.value = max(current_stats.health, dmg_value_result.value)
		if hitbox:
			hitbox.notify_one_shot_something(self)
	var full_dmg_value = dmg_value_result.value
	dmg_taken = clamp(full_dmg_value, 0, current_stats.health)
	current_stats.health = max(0.0, current_stats.health - full_dmg_value) as int

	if (is_crit or is_one_shot) and hitbox:
		hitbox.notify_critically_hit_something(self, dmg_taken)
		if hitbox.from != null:
			emit_signal("crit_effect", hitbox.from)

	if full_dmg_value > 0:
		flash()

	if args.custom_sound:
		sound = args.custom_sound

	SoundManager2D.play(sound, global_position, 0, 0.2)

	var final_knockback_amount = knockback_amount

	
	if final_knockback_amount < 0 and hitbox != null:
		final_knockback_amount = get_knockback_amount_based_on_distance_to_attacker(final_knockback_amount, hitbox, players_ref[from_player_index])
	elif knockback_piercing > 0:
		final_knockback_amount = get_increased_piercing_knockback_amount(knockback_amount, knockback_piercing, stats.knockback_resistance)

	knockback_vector = knockback_direction * final_knockback_amount
	emit_signal("health_updated", self, current_stats.health, max_stats.health)

	var hit_type = HitType.NORMAL

	for effect_behavior in effect_behaviors.get_children():
		var behavior_hit_type_result = effect_behavior.on_taken_damage(args)

		if behavior_hit_type_result != HitType.NORMAL:
			hit_type = behavior_hit_type_result

	if current_stats.health <= 0:
		if hitbox:
			hitbox.notify_killed_something(self)

		_die_args_unit.knockback_vector = knockback_direction * max(knockback_amount, MIN_DEATH_KNOCKBACK_AMOUNT)
		_die_args_unit.killed_by_player_index = from_player_index
		_die_args_unit.killing_blow_dmg_value = full_dmg_value
		_die_args_unit.is_burning = args.is_burning
		call_deferred("die", _die_args_unit)
		_pending_die = true

		if from_player_index >= 0 and Utils.get_chance_success(RunData.get_player_effect(Keys.heal_on_kill_hash, from_player_index) / 100.0):
			RunData.emit_signal("healing_effect", 1, from_player_index, Keys.item_goblet_hash)
		if is_crit:
			
			assert (from_player_index >= 0)

			
			
			
			

			var gold_added = 0
			var gold_on_crit_kill_effects = RunData.get_player_effect(Keys.gold_on_crit_kill_hash, from_player_index)
			for effect in gold_on_crit_kill_effects:
				if Utils.get_chance_success(effect[1] / 100.0):
					gold_added += 1
					RunData.add_tracked_value(from_player_index, Keys.item_hunting_trophy_hash, 1)

			if Utils.get_chance_success(RunData.get_player_effect(Keys.heal_on_crit_kill_hash, from_player_index) / 100.0):
				RunData.emit_signal("healing_effect", 1, from_player_index, Keys.item_tentacle_hash)

			for effect in hitbox.effects:
				if effect.key_hash == Keys.gold_on_crit_kill_hash and randf() <= effect.value / 100.0:
					gold_added += 1
					hitbox.notify_added_gold_on_crit(gold_added)

			if gold_added > 0:
				RunData.add_gold(gold_added, from_player_index)
				hit_type = HitType.GOLD_ON_CRIT_KILL

	emit_signal(
		"took_damage", 
		self, 
		full_dmg_value, 
		knockback_direction, 
		is_crit, 
		false, 
		false, 
		dmg_value_result.armor_did_something, 
		args, 
		hit_type, 
		is_one_shot
	)

	return [full_dmg_value, dmg_taken, false]


func get_knockback_amount_based_on_distance_to_attacker(base_amount: float, hitbox: Hitbox, attacker: Unit) -> float:
	var adjusted_amount = base_amount
	var direction_to_attacker = global_position.direction_to(attacker.global_position)
	var distance_to_attacker = global_position.distance_to(attacker.global_position)
	var movement_dot_product = direction_to_attacker.dot(_current_movement.normalized())
	var attacker_movement_dot_product = direction_to_attacker.dot(attacker._current_movement.normalized())

	var size_factor = _hurtbox._collision.shape.radius
	var attacker_size_factor = attacker._hurtbox._collision.shape.radius
	var speed_factor = movement_dot_product * current_stats.speed / 6.0
	var attacker_speed_factor = - (attacker_movement_dot_product * attacker.current_stats.speed / 6.0)

	
	if attacker_movement_dot_product > 0:
		attacker_speed_factor *= 0.1

	var buffer = size_factor + attacker_size_factor + speed_factor + attacker_speed_factor + min(distance_to_attacker / 3.0, 150.0)
	var max_travel_distance = max(0.0, distance_to_attacker - buffer)

	if max_travel_distance > THRESHOLD_DIST_TO_LOWER_DMG_ON_PULL:
		set_hitbox_damage_modifier()

	
	
	
	var expected_travel_distance = abs(base_amount * 100 / 6.0)

	if expected_travel_distance > max_travel_distance:
		adjusted_amount = - (max_travel_distance * 6.0 / 100.0)

	if hitbox.knockback_piercing > 0:
		adjusted_amount = get_increased_piercing_knockback_amount(adjusted_amount, hitbox.knockback_piercing, stats.knockback_resistance)

	add_decaying_speed( - adjusted_amount)

	return adjusted_amount


func set_hitbox_damage_modifier() -> void :
	pass



func get_increased_piercing_knockback_amount(amount: float, piercing: float, resistance: float) -> float:
	if resistance == 1:
		return amount
	return amount + (amount * min(resistance, piercing) / (1 - resistance))


class GetDamageValueResult:
	var value: int = 0
	var dodged: = false
	var protected: = false
	var armor_did_something: = false


func get_damage_value(dmg_value: int, from_player_index: int, armor_applied: = true, _dodgeable: = true, _is_crit: = false, hitbox: Hitbox = null, _p_is_burning: = false) -> GetDamageValueResult:
	var result = GetDamageValueResult.new()
	var total_bonus_damage = 0

	if hitbox:
		for effect in hitbox.effects:
			if effect.key_hash == Keys.bonus_damage_against_targets_above_hp_hash and current_stats.health >= (effect.value2 / 100.0) * max_stats.health:
				total_bonus_damage += effect.value
			elif effect.key_hash == Keys.bonus_damage_against_targets_below_hp_hash and current_stats.health <= (effect.value2 / 100.0) * max_stats.health:
				total_bonus_damage += effect.value

		if from_player_index >= 0:
			var bonus_non_elemental_damage_against_burning_targets = RunData.get_player_effect(Keys.bonus_non_elemental_damage_against_burning_targets_hash, from_player_index)
			if bonus_non_elemental_damage_against_burning_targets > 0 and _is_burning:
				var is_elemental = false
				for scaling_stat in hitbox.scaling_stats:
					assert (scaling_stat[0] is int)
					if scaling_stat[0] == Keys.stat_elemental_damage_hash:
						is_elemental = true
						break

				if not is_elemental:
					total_bonus_damage += bonus_non_elemental_damage_against_burning_targets

	for effect_behavior in effect_behaviors.get_children():
		total_bonus_damage += effect_behavior.get_bonus_damage(hitbox, from_player_index)

	if from_player_index >= 0:
		var bonus_damage_against_targets_above_hp_from_items = RunData.get_player_effect(Keys.bonus_damage_against_targets_above_hp_hash, from_player_index)
		if bonus_damage_against_targets_above_hp_from_items.size() > 0:
			assert (from_player_index >= 0)
			for bonus in bonus_damage_against_targets_above_hp_from_items:
				if current_stats.health >= (bonus[1] / 100.0) * max_stats.health:
					total_bonus_damage += bonus[0]

		var bonus_damage_against_targets_below_hp_from_items = RunData.get_player_effect(Keys.bonus_damage_against_targets_below_hp_hash, from_player_index)
		if bonus_damage_against_targets_below_hp_from_items.size() > 0:
			assert (from_player_index >= 0)
			for bonus in bonus_damage_against_targets_below_hp_from_items:
				if current_stats.health <= (bonus[1] / 100.0) * max_stats.health:
					total_bonus_damage += bonus[0]

	dmg_value = round(dmg_value * (1.0 + (total_bonus_damage / 100.0))) as int

	result.value = max(1, dmg_value - current_stats.armor) as int if armor_applied else dmg_value

	if armor_applied and dmg_value != result.value:
		result.armor_did_something = true

	return result


func flash() -> void :
	
	
	var is_already_flashing = sprite.material == flash_mat
	if not is_already_flashing:
		_non_flash_material = sprite.material
		sprite.material = flash_mat
	_flash_timer.start()


func die(args = Utils.default_die_args) -> void :
	if dead:
		return
	super.die(args)
	knockback_vector = args.knockback_vector
	_can_move = false
	_hurtbox.disable()
	for effect_behavior in effect_behaviors.get_children():
		effect_behavior.on_death(args)
		effect_behavior.queue_free()


func _on_hurt(_hitbox: Hitbox) -> void :
	pass


func hurt_area_entered_deferred(hitbox: Area2D) -> void :
	if get_parent() == null or not hitbox.active or hitbox.ignored_objects.has(self) or _pending_die:
		return

	var dmg_taken = [0, 0, false]

	if hitbox.deals_damage:
		var dmg = hitbox.damage
		var from = hitbox.from if is_instance_valid(hitbox.from) else null
		var from_player_index = from.player_index if (from != null and from.player_index != - 1) else RunData.DUMMY_PLAYER_INDEX

		
		for effect_behavior in effect_behaviors.get_children():
			effect_behavior.on_hurt(hitbox)
		_on_hurt(hitbox)

		var is_exploding = false
		for effect in hitbox.effects:
			if effect is ExplodingEffect:
				if Utils.get_chance_success(effect.chance):
					_explode_args_unit.pos = global_position
					_explode_args_unit.damage = hitbox.damage
					_explode_args_unit.accuracy = hitbox.accuracy
					_explode_args_unit.crit_chance = hitbox.crit_chance
					_explode_args_unit.crit_damage = hitbox.crit_damage
					_explode_args_unit.burning_data = hitbox.burning_data
					_explode_args_unit.scaling_stats = hitbox.scaling_stats
					_explode_args_unit.from_player_index = from_player_index
					_explode_args_unit.is_healing = hitbox.is_healing
					_explode_args_unit.damage_tracking_key_hash = hitbox.damage_tracking_key_hash

					var explosion = WeaponService.explode(effect, _explode_args_unit)
					if from != null and from is Weapon:
						explosion.connect("hit_something", Callable(from, "on_weapon_hit_something").bind(explosion._hitbox))
						if not explosion.is_connected("killed_something", Callable(from, "on_killed_something")):
							explosion.connect("killed_something", Callable(from, "on_killed_something").bind(explosion._hitbox))

					is_exploding = true
			elif effect.key_hash == Keys.stat_damage_hash and effect is PlayerHealthStatEffect:
				dmg += effect.get_bonus_damage(from_player_index)

		
		if not is_exploding:
			_take_damage_args_unit._init(from_player_index, hitbox)
			_take_damage_args_unit.from = from
			if hitbox.burning_data != null and Utils.get_chance_success(hitbox.burning_data.chance) and not hitbox.is_healing and RunData.get_player_effect(Keys.can_burn_enemies_hash, from_player_index) > 0:
				apply_burning(hitbox.burning_data)
				_take_damage_args_unit.is_burning = true
			dmg_taken = take_damage(dmg, _take_damage_args_unit)

		if hitbox.projectiles_on_hit.size() > 0:
			for i in hitbox.projectiles_on_hit[0]:
				_spawn_projectile_args.from_player_index = from_player_index
				var projectile = WeaponService.manage_special_spawn_projectile(
					self, 
					hitbox.projectiles_on_hit[1], 
					randf_range( - PI, PI), 
					hitbox.projectiles_on_hit[2], 
					_entity_spawner_ref, 
					from, 
					_spawn_projectile_args
				)
				if from != null and from is Weapon and not projectile.is_connected("hit_something", Callable(from, "on_weapon_hit_something")):
					projectile.connect("hit_something", Callable(from, "on_weapon_hit_something").bind(projectile._hitbox))
				if projectile.is_node_ready():
					projectile.set_ignored_objects([self])
				else:
					projectile.call_deferred("set_ignored_objects", [self])

		if hitbox.speed_percent_modifier != 0:
			add_decaying_speed((get_base_speed_value_for_pct_based_decrease() * hitbox.speed_percent_modifier / 100.0) as int)

	hitbox.notify_hit_something(self, dmg_taken[1])

func _on_Hurtbox_area_entered(hitbox: Area2D) -> void :
	call_deferred("hurt_area_entered_deferred", hitbox)


func get_base_speed_value_for_pct_based_decrease() -> int:
	return current_stats.speed


func apply_burning(burning_data: BurningData) -> void :
	if dead:
		
		return

	var from = burning_data.from
	var new_burning_player_index: int
	if is_instance_valid(from):
		new_burning_player_index = from.player_index
	else:
		new_burning_player_index = _burning_player_index if _burning_player_index >= 0 else Utils.randi() % RunData.get_player_count()

	if _burning != null:
		if _burning.damage <= burning_data.damage:
			_burning.scaling_stats = burning_data.scaling_stats
			_burning.from = from
			_burning_player_index = new_burning_player_index

		_burning.chance = max(_burning.chance, burning_data.chance)
		_burning.damage = max(_burning.damage, burning_data.damage) as int
		_burning.duration = max(_burning.duration, burning_data.duration) as int
		_burning.spread = max(_burning.spread, burning_data.spread) as int

	else:
		SoundManager2D.play(Utils.get_rand_element(burn_sounds), global_position, 0, 0.2)
		_burning = burning_data.duplicate()
		_burning_player_index = new_burning_player_index
		_burning_timer.start()
		set_burning(true)

	_burning_particles.burning_data = _burning
	_burning_particles.start_emitting()

	if _burning.spread > 0:
		_burning_particles.activate_spread()



func _on_FlashTimer_timeout() -> void :
	if sprite.material == flash_mat:
		sprite.material = _non_flash_material


func _on_BurningTimer_timeout() -> void :
	if _burning != null:
		
		for effect_behavior in effect_behaviors.get_children():
			effect_behavior.on_burned(_burning, _burning_player_index)

		var wasAlive = not self.dead
		
		_take_damage_args_unit._init(_burning_player_index)
		_take_damage_args_unit.dodgeable = false
		_take_damage_args_unit.armor_applied = false
		_take_damage_args_unit.custom_sound = Utils.get_rand_element(burn_sounds)
		_take_damage_args_unit.base_effect_scale = 0.1
		_take_damage_args_unit.is_burning = true
		var dmg_taken = take_damage(_burning.damage, _take_damage_args_unit)

		var slow_on_hit_effects = RunData.get_player_effect(Keys.slow_on_hit_hash, _burning_player_index)
		for slow_on_hit_effect in slow_on_hit_effects:
			assert (slow_on_hit_effect[0] is String)
			if slow_on_hit_effect[0] == "stat_elemental_damage":
				add_decaying_speed((current_stats.speed * - slow_on_hit_effect[1] / 100.0) as int)
				break

		if _burning.is_global_burn:
			RunData.add_tracked_value(_burning_player_index, Keys.item_scared_sausage_hash, dmg_taken[1])
		else:
			var nb_sausages = RunData.get_nb_item(Keys.item_scared_sausage_hash, _burning_player_index)
			RunData.add_tracked_value(_burning_player_index, Keys.item_scared_sausage_hash, min(nb_sausages, dmg_taken[1]))

		if Utils.get_first_scaling_stat(_burning.scaling_stats) == Keys.stat_engineering_hash:
			
			RunData.add_tracked_value(_burning_player_index, Keys.item_turret_flame_hash, dmg_taken[1])

		var from = _burning.from
		if is_instance_valid(from) and from.has_method("on_weapon_hit_something"):
			from.on_weapon_hit_something(self, dmg_taken[1], null)

		if not ChallengeService.is_challenge_completed(ChallengeService.chal_will_o_the_wisp_hash) and from != null and wasAlive and self._pending_die:
			RunData.players_data[from.player_index].chal_will_o_the_wisp += 1
			ChallengeService.try_complete_challenge(ChallengeService.chal_will_o_the_wisp_hash, RunData.players_data[from.player_index].chal_will_o_the_wisp)

		_burning.duration -= 1
		if _burning.duration <= 0:
			stop_burning()
		elif _burning.spread <= 0:
			_burning_particles.deactivate_spread()


func stop_burning() -> void :
	_burning_timer.stop()
	_burning_particles.stop_emitting_particles()
	set_burning(false)
	_burning = null


func set_burning(p_is_burning: bool) -> void :
	if p_is_burning:
		assert ( not dead)
	if not _is_burning and p_is_burning:
		RunData.current_burning_enemies += 1
	elif _is_burning and not p_is_burning:
		RunData.current_burning_enemies -= 1
	_is_burning = p_is_burning
	
	reset_speed_stat(_speed_percent_modifier)
	ChallengeService.try_complete_challenge(ChallengeService.chal_barbecue_hash, RunData.current_burning_enemies)


func add_decaying_speed(value: int, emit_signal: = true) -> void :

	if value < 0 and emit_signal:
		emit_signal("speed_removed", self)
	if decaying_bonus_speed < - (current_stats.speed * 0.7):
		return
	if decaying_bonus_speed < - (current_stats.speed * 0.45):
		value /= 20

	value = max(value, - current_stats.speed * 0.9) as int

	decaying_bonus_speed += value


func _on_moved(delta_position: Vector2) -> void :
	for effect_behavior in effect_behaviors.get_children():
		effect_behavior.on_moved(delta_position)


func _on_one_shotted(effect: OneShotOnHitEffect) -> void :
	SoundManager2D.play(effect.sound_one_shot, global_position, 0, 0.2)
	emit_signal("one_shot_effect", self)

func _get_health_effect_percent_factor() -> float:
	return 100.0


func _on_Hitbox_body_entered(_body: Node) -> void :
	pass
