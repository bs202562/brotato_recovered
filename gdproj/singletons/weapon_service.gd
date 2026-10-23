# 武器服务：计算运行时攻击属性，并统一生成子弹、爆炸和燃烧数据。
# 属性主线：init_*_stats → init_base_stats；发射主线：spawn_projectile → 子弹 shoot_ex。
extends Node

# 普通武器的最大射程至少为此值；有最小射程时，需在最小射程外再留出此范围。
const MIN_RANGE = 25
const DEFAULT_PROJECTILE_SCENE = preload("res://projectiles/bullet/bullet_projectile.tscn")
# 通用攻速计算的最低冷却帧数，冷却使用 60 帧制单位。
const MIN_COOLDOWN: = 2

# 默认子弹池使用路径哈希；自定义子弹池使用场景资源的实例 ID。
var default_projectile_pool_id = Keys.generate_hash("res://projectiles/bullet/bullet_projectile.tscn")

var breaking_sounds: Array = [
	preload("res://weapons/melee_sounds/glass_smashable_small_break_01.wav"), 
	preload("res://weapons/melee_sounds/glass_smashable_small_break_02.wav"), 
	preload("res://weapons/melee_sounds/glass_smashable_small_break_03.wav"), 
]

# 复用的默认参数与命中盒参数对象，并非每次调用都自动创建独立副本。
var _init_stats_args_service: = WeaponServiceInitStatsArgs.new()
var _default_spawn_projectile_args: = WeaponServiceSpawnProjectileArgs.new()
var _hitbox_args = Hitbox.HitboxArgs.new()


# 生成近战运行时属性：共用属性计算后，叠加一半的玩家范围属性，并保留攻击类型。
func init_melee_stats(from_stats: MeleeWeaponStats, player_index: int, args: WeaponServiceInitStatsArgs = _init_stats_args_service) -> MeleeWeaponStats:
	var new_stats = init_base_stats(from_stats, player_index, args) as MeleeWeaponStats
	new_stats.alternate_attack_type = from_stats.alternate_attack_type

	var min_range = MIN_RANGE

	if new_stats.min_range != 0:
		min_range = new_stats.min_range + MIN_RANGE

	new_stats.max_range = max(min_range, new_stats.max_range + (Utils.get_stat(Keys.stat_range_hash, player_index) / 2.0)) as int

	return new_stats


# 生成远程运行时属性：叠加完整范围属性，再计算弹数、穿透、弹射和弹速。
func init_ranged_stats(from_stats: RangedWeaponStats, player_index: int, is_special_spawn: = false, args: WeaponServiceInitStatsArgs = _init_stats_args_service) -> RangedWeaponStats:
	var new_stats = init_base_stats(from_stats, player_index, args, false, is_special_spawn) as RangedWeaponStats

	var min_range = MIN_RANGE

	if new_stats.min_range != 0:
		min_range = new_stats.min_range + MIN_RANGE

	new_stats.max_range = max(min_range, new_stats.max_range + Utils.get_stat(Keys.stat_range_hash, player_index)) as int
	_set_common_ranged_stats(new_stats, from_stats, player_index)
	return new_stats


# 生成建筑攻击属性：使用建筑标记及专属范围属性，再补充远程参数。
func init_structure_stats(from_stats: RangedWeaponStats, player_index: int, args: WeaponServiceInitStatsArgs = _init_stats_args_service) -> RangedWeaponStats:
	var is_structure: = true
	var new_stats = init_base_stats(from_stats, player_index, args, is_structure) as RangedWeaponStats

	new_stats.max_range = max(MIN_RANGE, new_stats.max_range + Utils.get_stat(Keys.structure_range_hash, player_index))

	_set_common_ranged_stats(new_stats, from_stats, player_index)

	return new_stats

# 生成近战宠物属性，启用宠物属性换算；范围仍按近战规则增加。
func init_melee_pet_stats(from_stats: MeleeWeaponStats, player_index: int, args: = WeaponServiceInitStatsArgs.new()) -> MeleeWeaponStats:
	var new_stats = init_base_stats(from_stats, player_index, args, false, false, true) as MeleeWeaponStats
	new_stats.alternate_attack_type = from_stats.alternate_attack_type

	var min_range = MIN_RANGE

	if new_stats.min_range != 0:
		min_range = new_stats.min_range + MIN_RANGE

	new_stats.max_range = max(min_range, new_stats.max_range + (Utils.get_stat(Keys.stat_range_hash, player_index) / 2.0)) as int

	return new_stats

# 生成远程宠物属性，启用宠物属性换算并补充远程参数。
func init_ranged_pet_stats(from_stats: RangedWeaponStats, player_index: int, is_special_spawn: = false, args: = WeaponServiceInitStatsArgs.new()) -> RangedWeaponStats:
	var new_stats = init_base_stats(from_stats, player_index, args, false, is_special_spawn, true) as RangedWeaponStats

	var min_range = MIN_RANGE

	if new_stats.min_range != 0:
		min_range = new_stats.min_range + MIN_RANGE

	new_stats.max_range = max(min_range, new_stats.max_range + Utils.get_stat(Keys.stat_range_hash, player_index)) as int
	_set_common_ranged_stats(new_stats, from_stats, player_index)
	return new_stats

# 生成同时属于建筑和宠物的攻击属性，使用建筑范围及两种身份的加成分支。
func init_structure_pet_stats(from_stats: RangedWeaponStats, player_index: int, args: = WeaponServiceInitStatsArgs.new()) -> RangedWeaponStats:
	var new_stats = init_base_stats(from_stats, player_index, args, true, false, true) as RangedWeaponStats

	new_stats.max_range = max(MIN_RANGE, new_stats.max_range + Utils.get_stat(Keys.structure_range_hash, player_index))

	_set_common_ranged_stats(new_stats, from_stats, player_index)

	return new_stats


# 填充远程共用属性；穿透/弹射伤害加成会降低对应的伤害衰减比例。
func _set_common_ranged_stats(new_stats: RangedWeaponStats, from_stats: RangedWeaponStats, player_index: int):
	var projectiles_effect = RunData.get_player_effect(Keys.projectiles_hash, player_index)
	new_stats.projectile_spread = from_stats.projectile_spread + (projectiles_effect * 0.1)

	# 基础弹数为 0 的配置不在这里获得额外弹数。
	if from_stats.nb_projectiles > 0:
		new_stats.nb_projectiles = from_stats.nb_projectiles + projectiles_effect

	var piercing_dmg_bonus = (Utils.get_stat(Keys.piercing_damage_hash, player_index) / 100.0)
	var bounce_dmg_bonus = (Utils.get_stat(Keys.bounce_damage_hash, player_index) / 100.0)

	new_stats.piercing = from_stats.piercing + RunData.get_player_effect(Keys.piercing_hash, player_index)
	new_stats.piercing_dmg_reduction = clamp(from_stats.piercing_dmg_reduction - piercing_dmg_bonus, 0, 1)

	if from_stats.can_bounce:
		new_stats.bounce = from_stats.bounce + RunData.get_player_effect(Keys.bounce_hash, player_index)
	else:
		new_stats.bounce = 0

	new_stats.bounce_dmg_reduction = clamp(from_stats.bounce_dmg_reduction - bounce_dmg_bonus, 0, 1)
	new_stats.projectile_scene = from_stats.projectile_scene

	if from_stats.increase_projectile_speed_with_range:
		var stat_range = Utils.get_stat(Keys.stat_range_hash, player_index)
		new_stats.projectile_speed = clamp(from_stats.projectile_speed + (from_stats.projectile_speed / 300.0) * stat_range, 50, 6000) as int
	else:
		new_stats.projectile_speed = from_stats.projectile_speed

# 按近战/远程类型新建属性对象，依次应用武器类型、套装、效果、攻速和伤害等加成。
# is_structure、is_special_spawn、is_pet 决定参与哪些加成；并非对原资源做完整深复制。
func init_base_stats(from_stats: WeaponStats, player_index: int, args: WeaponServiceInitStatsArgs = _init_stats_args_service, is_structure: = false, is_special_spawn: = false, is_pet: = false) -> WeaponStats:
	var new_stats: WeaponStats
	if from_stats is MeleeWeaponStats:
		new_stats = MeleeWeaponStats.new()
	else:
		new_stats = RangedWeaponStats.new()

	
	new_stats.cooldown = from_stats.cooldown
	new_stats.damage = from_stats.damage
	new_stats.accuracy = from_stats.accuracy
	new_stats.crit_chance = from_stats.crit_chance
	new_stats.crit_damage = from_stats.crit_damage
	new_stats.min_range = from_stats.min_range
	new_stats.max_range = from_stats.max_range
	new_stats.knockback = from_stats.knockback
	new_stats.knockback_piercing = from_stats.knockback_piercing
	new_stats.can_have_positive_knockback = from_stats.can_have_positive_knockback
	new_stats.can_have_negative_knockback = from_stats.can_have_negative_knockback
	new_stats.effect_scale = from_stats.effect_scale
	new_stats.scaling_stats = Utils.convert_to_hash_array(from_stats.scaling_stats)
	new_stats.lifesteal = from_stats.lifesteal
	new_stats.shooting_sounds = from_stats.shooting_sounds
	new_stats.sound_db_mod = from_stats.sound_db_mod
	new_stats.is_healing = from_stats.is_healing
	new_stats.recoil = from_stats.recoil
	new_stats.recoil_duration = from_stats.recoil_duration
	new_stats.additional_cooldown_every_x_shots = from_stats.additional_cooldown_every_x_shots
	new_stats.additional_cooldown_multiplier = from_stats.additional_cooldown_multiplier
	new_stats.speed_percent_modifier = from_stats.speed_percent_modifier

	new_stats.burning_data = from_stats.burning_data
	new_stats.burning_data._late_init()
	new_stats.attack_speed_mod = from_stats.attack_speed_mod

	
	for weapon_type_bonus in RunData.get_player_effect(Keys.weapon_type_bonus_hash, player_index):
		var weapon_type = weapon_type_bonus[0]
		var stat_name = Keys.hash_to_string[weapon_type_bonus[1]]
		var effect_value = weapon_type_bonus[2]

		if new_stats is RangedWeaponStats and weapon_type == WeaponType.RANGED:
			var value = new_stats.get(stat_name) + effect_value
			new_stats.set(stat_name, value)
		if new_stats is MeleeWeaponStats and weapon_type == WeaponType.MELEE:
			var value = new_stats.get(stat_name) + effect_value
			new_stats.set(stat_name, value)

	# 套装百分比伤害留到最终乘区合计；其他套装属性直接修改对应字段。
	var set_bonus_dmg: = 0.0
	for class_bonus in RunData.get_player_effect(Keys.weapon_class_bonus_hash, player_index):
		var set_id = class_bonus[0]
		var stat_h = class_bonus[1]
		var stat_name = Keys.hash_to_string[stat_h]
		var effect_value = class_bonus[2]
		for set in args.sets:
			assert (set_id is int)
			if set.my_id_hash == set_id:
				if stat_h == Keys.stat_percent_damage_hash:
					set_bonus_dmg += effect_value / 100.0
				else:
					var value = new_stats.get(stat_name) + effect_value
					if stat_h == Keys.lifesteal_hash or stat_h == Keys.crit_damage_hash:
						value = new_stats.get(stat_name) + (effect_value / 100.0)
					new_stats.set(stat_name, value)

	# 处理武器自带的燃烧、爆炸、减速、同类武器叠加及永久属性换算效果。
	var is_exploding: = false
	for effect in args.effects:
		if effect is BurningEffect:
			new_stats.burning_data = effect.burning_data
		elif effect is ExplodingEffect:
			is_exploding = true
		elif effect is WeaponSlowOnHitEffect:
			new_stats.speed_percent_modifier += effect.get_speed_percent_modifier(player_index)
		elif effect is WeaponStackEffect:
			var nb_same_weapon = 0
			for checked_weapon in RunData.get_player_weapons_ref(player_index):
				if checked_weapon.weapon_id_hash == effect.weapon_stacked_id_hash:
					nb_same_weapon += 1
			new_stats.set(effect.stat_name, new_stats.get(effect.stat_name) + (effect.value * max(0.0, nb_same_weapon - 1)))

		elif effect is WeaponGainStatForEveryStatEffect:
			var perm_stats_only = true
			var bonus = RunData.get_scaling_bonus(effect.value, effect.stat_scaled, effect.nb_stat_scaled, perm_stats_only, player_index)
			new_stats.set(effect.increased_stat_name, new_stats.get(effect.increased_stat_name) + bonus)

	if is_pet:
		new_stats.scaling_stats = _apply_beast_master_weapon_scaling_stat_effects(new_stats.scaling_stats, player_index)

	# 非建筑且非特殊生成的攻击，以及建筑宠物，可获得额外武器属性换算。
	if not is_structure and not is_special_spawn or (is_structure and is_pet):
		new_stats.scaling_stats = _apply_weapon_scaling_stat_effects(new_stats.scaling_stats, player_index)

	var slow_on_hit_effects = RunData.get_player_effect(Keys.slow_on_hit_hash, player_index)
	for slow_on_hit_effect in slow_on_hit_effects:
		assert (slow_on_hit_effect[0] is int)
		if find_scaling_stat(slow_on_hit_effect[0], new_stats.scaling_stats) != null:
			new_stats.speed_percent_modifier -= slow_on_hit_effect[1]
			break

	
	# 此处只传递建筑标记，没有把 is_pet 传给燃烧初始化。
	new_stats.burning_data = init_burning_data(new_stats.burning_data, player_index, is_structure)

	
	var atk_spd = (Utils.get_stat(Keys.stat_attack_speed_hash, player_index) + new_stats.attack_speed_mod) / 100.0
	# 建筑和宠物在这里不使用普通攻速；建筑另有专用攻速计算入口。
	if is_structure or is_pet:
		atk_spd = 0
	
	
	
	if new_stats.cooldown < MIN_COOLDOWN:
		new_stats.cooldown = MIN_COOLDOWN
	new_stats.cooldown = apply_attack_speed_mod_to_cooldown(new_stats.cooldown, atk_spd)
	if atk_spd > 0:
		new_stats.recoil /= 1 + atk_spd
		new_stats.recoil_duration /= 1 + atk_spd
	_apply_min_cooldown_effect(new_stats, player_index)
	_apply_max_cooldown_effect(new_stats, player_index)

	
	new_stats.damage = apply_scaling_stats_to_damage(new_stats.damage, new_stats.scaling_stats, player_index)

	var percent_dmg_bonus = (1 + (Utils.get_stat(Keys.stat_percent_damage_hash, player_index) / 100.0))
	if is_structure and not is_pet:
		percent_dmg_bonus = (1 + (Utils.get_stat(Keys.structure_percent_damage_hash, player_index) / 100.0))
	elif is_structure and is_pet:
		percent_dmg_bonus += Utils.get_stat(Keys.structure_percent_damage_hash, player_index) / 100.0

	var exploding_dmg_bonus = 0
	if is_exploding:
		exploding_dmg_bonus = (Utils.get_stat(Keys.explosion_damage_hash, player_index) / 100.0)

	# 套装、伤害百分比和爆炸加成相加后统一乘伤害，而非分别相乘。
	new_stats.damage = max(1, round(new_stats.damage * (set_bonus_dmg + percent_dmg_bonus + exploding_dmg_bonus))) as int

	
	if not is_structure or RunData.get_player_effect_bool(Keys.structures_can_crit_hash, player_index):
		new_stats.crit_chance += Utils.get_capped_stat(Keys.stat_crit_chance_hash, player_index) / 100.0

	
	new_stats.accuracy += RunData.get_player_effect(Keys.accuracy_hash, player_index) / 100.0

	
	if not is_structure:
		new_stats.lifesteal += Utils.get_stat(Keys.stat_lifesteal_hash, player_index) / 100.0

	
	# 先按武器允许的推开/吸引方向限制击退，再处理反向击退效果。
	var min_knockback = - Utils.LARGE_NUMBER if new_stats.can_have_negative_knockback else 0
	var max_knockback = Utils.LARGE_NUMBER if new_stats.can_have_positive_knockback else 0
	var player_knockback = RunData.get_player_effect(Keys.knockback_hash, player_index)

	if new_stats.can_have_negative_knockback and not new_stats.can_have_positive_knockback:
		player_knockback = - player_knockback

	new_stats.knockback = clamp(new_stats.knockback + player_knockback, min_knockback, max_knockback) as int
	if RunData.get_player_effect_bool(Keys.negative_knockback_hash, player_index):
		if from_stats.knockback < 0:
			new_stats.knockback -= player_knockback
		elif new_stats.knockback >= 0:
			new_stats.knockback *= - 1

	return new_stats



# 计算独立爆炸伤害：基础伤害加属性换算，再乘普通伤害与爆炸伤害加成，最低为 1。
func get_explosion_damage(from_stats: WeaponStats, player_index: int) -> int:
	var scaling_stats = _apply_weapon_scaling_stat_effects(from_stats.scaling_stats, player_index)
	var damage = apply_scaling_stats_to_damage(from_stats.damage, scaling_stats, player_index)
	var percent_dmg_bonus = (1 + (Utils.get_stat(Keys.stat_percent_damage_hash, player_index) / 100.0))
	var exploding_dmg_bonus = (Utils.get_stat(Keys.explosion_damage_hash, player_index) / 100.0)
	return max(1, round(damage * (percent_dmg_bonus + exploding_dmg_bonus))) as int



# 构建燃烧数据，合并武器自带燃烧与玩家全局燃烧，再计算属性换算、伤害及传播。
func init_burning_data(base_burning_data: BurningData, player_index: int, is_structure: bool = false, is_pet: bool = false) -> BurningData:
	var global_burning = RunData.get_player_effect(Keys.burn_chance_hash, player_index)

	var no_global_burning = global_burning.is_not_burning()
	var base_weapon_has_no_burning = base_burning_data.is_not_burning()

	var new_burning_data: = BurningData.new()

	if no_global_burning and base_weapon_has_no_burning:
		return new_burning_data

	new_burning_data.chance = base_burning_data.chance
	new_burning_data.damage = base_burning_data.damage
	new_burning_data.duration = base_burning_data.duration
	new_burning_data.spread = base_burning_data.spread
	new_burning_data.scaling_stats = Utils.convert_to_hash_array(base_burning_data.scaling_stats)

	# 已是全局燃烧时直接计算伤害并返回，不重复合并全局燃烧配置。
	if base_burning_data.is_global_burn:
		new_burning_data.damage = apply_scaling_stats_to_damage(new_burning_data.damage, new_burning_data.scaling_stats, player_index)
		new_burning_data.damage = apply_damage_bonus(new_burning_data.damage, player_index)
		return new_burning_data

	if is_pet:
		new_burning_data.scaling_stats = _apply_beast_master_weapon_scaling_stat_effects(new_burning_data.scaling_stats, player_index)

	
	# 无自带燃烧时采用全局配置；有自带燃烧时只叠加全局燃烧的基础伤害。
	if base_weapon_has_no_burning:
		
		new_burning_data.chance = global_burning.chance
		new_burning_data.duration = global_burning.duration
		new_burning_data.scaling_stats = Utils.convert_to_hash_array(global_burning.scaling_stats)
		new_burning_data.spread = global_burning.spread
		new_burning_data.damage = global_burning.damage
		new_burning_data.is_global_burn = true

	else:
		new_burning_data.damage += global_burning.damage

	new_burning_data.damage = apply_scaling_stats_to_damage(new_burning_data.damage, new_burning_data.scaling_stats, player_index)
	if is_structure and not base_weapon_has_no_burning:
		new_burning_data.damage = apply_structure_damage_bonus(new_burning_data.damage, player_index)
	else:
		new_burning_data.damage = apply_damage_bonus(new_burning_data.damage, player_index)

	new_burning_data.spread += RunData.get_player_effect(Keys.burning_spread_hash, player_index)

	return new_burning_data


# 处理特殊来源的发射：播放音效，可随机选敌人瞄准，再以延迟方式生成子弹。
# 此方法会修改传入 args 的 deferred 和 knockback_direction。
func manage_special_spawn_projectile(
	entity_from, 
	weapon_stats: RangedWeaponStats, 
	direction: float, 
	auto_target_enemy: bool, 
	entity_spawner_ref: EntitySpawner, 
	from: Node, 
	args: WeaponServiceSpawnProjectileArgs = _default_spawn_projectile_args
) -> Node:
	var pos = entity_from.global_position

	if weapon_stats.shooting_sounds.size() > 0:
		SoundManager2D.play(Utils.get_rand_element(weapon_stats.shooting_sounds), pos, 0, 0.2)

	if auto_target_enemy:
		var target = entity_spawner_ref.get_rand_enemy(entity_from)

		if target != null and is_instance_valid(target):
			direction = (target.global_position - pos).angle()

	args.deferred = true
	args.knockback_direction = Vector2(cos(direction), sin(direction))
	var projectile = spawn_projectile(pos, weapon_stats, direction, from, args)

	return projectile


# 从对象池取出或实例化一颗子弹，复制附加效果，再调用 shoot_ex 初始化发射。
# direction 为弧度；调用方通过 args 指定玩家归属、伤害统计键、击退方向和是否延迟。
func spawn_projectile(
	pos: Vector2, 
	weapon_stats: RangedWeaponStats, 
	direction: float, 
	from: Node, 
	args: WeaponServiceSpawnProjectileArgs
) -> Node:
	_hitbox_args.set_from_weapon_stats(weapon_stats)

	# 逐个复制效果对象，避免叠加玩家效果时改动传入的武器效果。
	var duplicated_effects = []
	for effect in args.effects:
		duplicated_effects.push_back(effect.duplicate())
	duplicated_effects = set_projectile_effects(duplicated_effects, args.from_player_index)

	var main = Utils.get_scene_node()

	var projectile_pool_id: int = default_projectile_pool_id

	if weapon_stats.projectile_scene != null:
		projectile_pool_id = weapon_stats.projectile_scene.get_instance_id()

	# 优先复用池中子弹，没有有效实例才创建并加入场景。
	var projectile = main.get_node_from_pool(projectile_pool_id, main._player_projectiles)
	if not is_instance_valid(projectile):
		var projectile_scene = weapon_stats.projectile_scene if weapon_stats.projectile_scene != null else DEFAULT_PROJECTILE_SCENE
		projectile = projectile_scene.instance()
		if args.deferred:
			main.call_deferred("add_player_projectile", projectile)
		else:
			main.add_player_projectile(projectile)

		projectile.set_meta("pool_id", projectile_pool_id)

	if args.deferred:
		
		# 延迟初始化与延迟添加节点配套使用，推迟场景操作。
		projectile.call_deferred("shoot_ex", 
			from, 
			pos, 
			Vector2.RIGHT.rotated(direction) * weapon_stats.projectile_speed, 
			(Vector2.RIGHT.rotated(direction) * weapon_stats.projectile_speed).angle(), 
			weapon_stats, 
			args.damage_tracking_key_hash, 
			duplicated_effects, 
			_hitbox_args, 
			args.knockback_direction)
	else:
		projectile.shoot_ex(
			from, 
			pos, 
			Vector2.RIGHT.rotated(direction) * weapon_stats.projectile_speed, 
			(Vector2.RIGHT.rotated(direction) * weapon_stats.projectile_speed).angle(), 
			weapon_stats, 
			args.damage_tracking_key_hash, 
			duplicated_effects, 
			_hitbox_args, 
			args.knockback_direction)

	return projectile


# 浅复制效果数组，并为有效玩家追加暴击穿透/弹射效果；已有的效果对象仍可能被修改。
func set_projectile_effects(base_effects: Array, player_index: int = - 1) -> Array:
	var all_effects = base_effects.duplicate()

	if player_index >= 0:
		all_effects = _add_player_effect_to_effects(all_effects, "pierce_on_crit", Keys.pierce_on_crit_hash, player_index)
		all_effects = _add_player_effect_to_effects(all_effects, "bounce_on_crit", Keys.bounce_on_crit_hash, player_index)

	return all_effects


# 把正数玩家效果叠加到同 key_hash 的效果上；没有匹配项时创建 NullEffect 作为数值载体。
func _add_player_effect_to_effects(effects: Array, key: String, key_hash: int, player_index: int) -> Array:
	
	var player_effect: int = RunData.get_player_effect(key_hash, player_index)
	if player_effect <= 0:
		return effects
	var found: = false
	for effect in effects:
		if effect.key_hash == key_hash:
			effect.value += player_effect
			found = true
	if not found:
		var effect: = NullEffect.new()
		effect.key = key
		effect.key_hash = key_hash
		effect.value = player_effect
		effects.append(effect)

	return effects



# 把 [属性哈希, 换算系数] 列表转换为说明界面的属性图标文本。
func get_scaling_stats_icon_text(p_scaling_stats: Array) -> String:
	var stat_icon_text: = ""
	for i in p_scaling_stats.size():
		assert (p_scaling_stats[i][0] is int)
		stat_icon_text += Utils.get_scaling_stat_icon_text(p_scaling_stats[i][0], p_scaling_stats[i][1])
	return stat_icon_text

# 检查换算列表中是否包含指定属性哈希。
func has_scaling_stats_hash(p_scaling_stats: Array, stat_name_hash: int) -> bool:
	for i in p_scaling_stats.size():
		if stat_name_hash == p_scaling_stats[i][0]:
			return true
	return false

# 累加 属性值 × 系数；等级属性直接读取玩家等级，其余属性通过 Utils 查询。
func sum_scaling_stat_values(p_scaling_stats: Array, player_index: int) -> float:
	var value = 0
	for scaling_stat in p_scaling_stats:
		assert (scaling_stat[0] is int)
		if scaling_stat[0] == Keys.stat_levels_hash:
			value += RunData.get_player_level(player_index) * scaling_stat[1]
		else:
			value += Utils.get_stat(scaling_stat[0], player_index) * scaling_stat[1]

	return value


# 返回第一个匹配的 [属性哈希, 系数] 条目引用，未找到时返回 null。
func find_scaling_stat(stat_id: int, scaling_stats: Array):
	for scaling_stat in scaling_stats:
		assert (scaling_stat[0] is int)
		if scaling_stat[0] == stat_id:
			return scaling_stat
	return null


# 将属性换算值加到基础伤害，最低为 1，再转换为整数。
func apply_scaling_stats_to_damage(damage: int, p_scaling_stats: Array, player_index: int) -> int:
	return max(1.0, damage + sum_scaling_stat_values(p_scaling_stats, player_index)) as int


# 应用玩家普通百分比伤害加成，四舍五入且结果最低为 1。
func apply_damage_bonus(value: int, player_index: int) -> int:
	var percent_dmg_bonus = 1 + Utils.get_stat(Keys.stat_percent_damage_hash, player_index) / 100.0
	return max(1, round(max(1, value) * percent_dmg_bonus)) as int


# 应用建筑专属百分比伤害加成，四舍五入且结果最低为 1。
func apply_structure_damage_bonus(value: int, player_index: int) -> int:
	var percent_dmg_bonus = 1 + Utils.get_stat(Keys.structure_percent_damage_hash, player_index) / 100.0
	return max(1, round(max(1, value) * percent_dmg_bonus)) as int



# 按已损失生命百分比换算增量：每损失 per_health_percent_amount 个百分点获得 value。
# 最大生命为 0 时返回 0；调用方需保证百分比步长不为 0。
func apply_inverted_health_bonus(value: int, per_health_percent_amount: int, current_health: int, max_health: int) -> int:
	if max_health == 0:
		return 0
	var percent_missing_health: = max(0.0, 1.0 - float(current_health) / float(max_health)) * 100.0
	return round(value * (percent_missing_health / per_health_percent_amount)) as int


# 从对象池取得或创建爆炸节点，设置归属、伤害、位置、范围及烟雾后启动爆炸。
func explode(effect: ExplodingEffect, args: WeaponServiceExplodeArgs) -> Node:
	var main: Main = Utils.get_scene_node()
	var instance = main.get_node_from_pool(effect.explosion_scene.get_instance_id(), main._explosions)

	if instance == null:
		instance = effect.explosion_scene.instance()
		main.add_explosion(instance)

	# 迷雾波次还需要向迷雾视口登记爆炸。
	if main._is_fog_wave:
		main._fog_viewport._on_spawn_explosion(instance)
	instance.pool_id = effect.explosion_scene.get_instance_id()
	instance.player_index = args.from_player_index
	instance.global_position = args.pos
	instance.sound_db_mod = effect.sound_db_mod
	instance.set_damage_tracking_key(args.damage_tracking_key_hash)
	instance.set_damage(args)
	instance.set_smoke_amount(round(effect.scale * effect.base_smoke_amount))
	instance.set_area(effect.scale)
	if args.from != null:
		instance.set_from(args.from)

	instance.start_explosion()

	return instance


# 判断死亡是否触发地雷：概率成功且来源武器含指定换算属性，或元素条件匹配死亡前燃烧状态。
func should_spawn_landmines_on_enemy_death(hitbox: Hitbox, was_burning: bool, player_index: int) -> bool:
	var from = hitbox.from if hitbox != null else null
	var landmines_on_death_effects = RunData.get_player_effect(Keys.landmines_on_death_chance_hash, player_index)
	for landmines_on_death_effect in landmines_on_death_effects:
		var effect_stat = landmines_on_death_effect[0]
		assert (effect_stat is int)
		var chance = landmines_on_death_effect[1] / 100.0
		if not Utils.get_chance_success(chance):
			continue
		var weapon_did_stat_damage = from is Weapon and find_scaling_stat(effect_stat, from.current_stats.scaling_stats) != null
		var burning_did_stat_damage = effect_stat == Keys.stat_elemental_damage_hash and was_burning
		if weapon_did_stat_damage or burning_did_stat_damage:
			return true
	return false


# 返回建筑攻速百分数，合计专属攻速和按玩家属性换算的效果。
func get_structure_attack_speed(player_index: int) -> float:
	var structure_attack_speed = Utils.get_stat(Keys.structure_attack_speed_hash, player_index)
	var effect_scaling_stats = RunData.get_player_effect(Keys.structures_cooldown_reduction_hash, player_index)
	var scaling_stats = []
	for effect_scaling_stat in effect_scaling_stats:
		scaling_stats.push_back([effect_scaling_stat[0], effect_scaling_stat[1] / 100.0])
	return sum_scaling_stat_values(scaling_stats, player_index) + structure_attack_speed


# 将建筑攻速换算为冷却；非正数基础冷却直接保留。
func apply_structure_attack_speed_effects(base_cooldown: int, player_index: int) -> int:
	if base_cooldown <= 0:
		return base_cooldown
	var total_attack_speed_percent = get_structure_attack_speed(player_index) / 100.0
	base_cooldown = apply_attack_speed_mod_to_cooldown(base_cooldown, total_attack_speed_percent)
	return base_cooldown


# 应用攻速比例（0.2 表示 +20%）：正攻速用除法缩短冷却，负攻速用乘法延长。
# 冷却按整数帧计算，结果不低于 MIN_COOLDOWN。
func apply_attack_speed_mod_to_cooldown(base_cooldown: int, attack_speed_mod: float) -> int:
	if attack_speed_mod < 0:
		return max(MIN_COOLDOWN, base_cooldown * (1 + abs(attack_speed_mod))) as int
	return max(MIN_COOLDOWN, base_cooldown / (1 + attack_speed_mod)) as int


# 用效果列表最后一个值限制最低总冷却；把显示的秒数换算成 60 帧制再补足基础冷却。
func _apply_min_cooldown_effect(stats: WeaponStats, player_index: int) -> void :
	var min_cooldown_effects = RunData.get_player_effect(Keys.minimum_weapon_cooldowns_hash, player_index)
	if min_cooldown_effects.empty():
		return
	
	var min_cooldown_effect_value: int = min_cooldown_effects.back()
	assert (min_cooldown_effect_value >= MIN_COOLDOWN)
	
	
	var total_cooldown_seconds: = stats.get_cooldown_value(player_index, 1.0)
	var total_cooldown: = total_cooldown_seconds * 60.0
	var cooldown_below_min: = min_cooldown_effect_value - total_cooldown
	if cooldown_below_min <= 0:
		return

	
	
	
	var new_cooldown = stats.cooldown + ceil(cooldown_below_min) as int

	
	
	# 基础冷却增大后下调周期性额外冷却倍率，最低保留为 1。
	if stats.additional_cooldown_every_x_shots != - 1:
		stats.additional_cooldown_multiplier = max(1, (stats.additional_cooldown_multiplier * stats.cooldown) / new_cooldown)

	stats.cooldown = new_cooldown


# 用效果列表第一个值限制最高总冷却；超出部分从基础冷却中扣除。
func _apply_max_cooldown_effect(stats: WeaponStats, player_index: int) -> void :
	var max_cooldown_effects = RunData.get_player_effect(Keys.maximum_weapon_cooldowns_hash, player_index)
	if max_cooldown_effects.empty():
		return

	var max_cooldown_value: int = max_cooldown_effects[0]
	var total_cooldown_seconds: = stats.get_cooldown_value(player_index, 1.0)
	var total_cooldown: = total_cooldown_seconds * 60.0

	var cooldown_above_max: = total_cooldown - max_cooldown_value
	if cooldown_above_max <= 0:
		return

	stats.cooldown -= ceil(cooldown_above_max) as int


# 把额外武器属性换算效果合并到列表；有效果时深复制，避免改动传入的系数。
func _apply_weapon_scaling_stat_effects(scaling_stats: Array, player_index: int) -> Array:
	var weapon_scaling_stat_effects = RunData.get_player_effect(Keys.weapon_scaling_stats_hash, player_index)
	if weapon_scaling_stat_effects.empty():
		return scaling_stats
	var new_scaling_stats = scaling_stats.duplicate(true)
	for scaling_stat_effect in weapon_scaling_stat_effects:
		assert (scaling_stat_effect[0] is int)
		var scaling_stat_hash = scaling_stat_effect[0]
		var scaling_stat_value = scaling_stat_effect[1] / 100.0
		var existing_scaling_stat = find_scaling_stat(scaling_stat_hash, new_scaling_stats)
		if existing_scaling_stat != null:
			existing_scaling_stat[1] += scaling_stat_value
		else:
			new_scaling_stats.push_back([scaling_stat_hash, scaling_stat_value])
	return new_scaling_stats

# 驯兽师效果启用且列表非空时，以首个系数补齐缺失的近战、远程、元素和工程换算。
func _apply_beast_master_weapon_scaling_stat_effects(scaling_stats: Array, player_index: int) -> Array:
	if RunData.get_player_effects(player_index).has(Keys.stat_beast_master_effect_hash) and RunData.get_player_effect_bool(Keys.stat_beast_master_effect_hash, player_index):
		var damage_stats = Utils.convert_to_hash_array(["stat_melee_damage", "stat_ranged_damage", "stat_elemental_damage", "stat_engineering"])
		var new_scaling_stats = scaling_stats.duplicate(true)
		if new_scaling_stats.size() > 0:
			var value = new_scaling_stats[0][1]
			for stats in new_scaling_stats:
				damage_stats.erase(stats[0])

			for stat_name in damage_stats:
				new_scaling_stats.push_back([stat_name, value])

			return new_scaling_stats
	return scaling_stats


# 生成“每 X 次发射”的特殊远程属性表，键为 effect.value。
# 临时应用子效果以重算属性，随后撤销；相同键会被后续结果覆盖。
func init_stats_every_x_projectiles(base_stats: WeaponStats, player_index: int, args: WeaponServiceInitStatsArgs) -> Dictionary:
	
	var modify_projectile_effects = []
	# 弹数增量在整个效果循环中累计，用于额外散射修正，不会每轮清零。
	var nb_projectile_effect = 0
	var item_effects = RunData.get_player_effect(Keys.modify_every_x_projectile_hash, player_index)
	modify_projectile_effects.append_array(item_effects)

	for effect in args.effects:
		if effect is WeaponEffectWithSubEffects:
			modify_projectile_effects.push_back(effect)

	var stats_every_x_shots = {}

	for effect in modify_projectile_effects:
		for sub_effect in effect.sub_effects:
			sub_effect.apply(player_index)
			if sub_effect.key_hash == Keys.projectiles_hash:
				nb_projectile_effect += sub_effect.value

		var modified_stats: RangedWeaponStats = init_ranged_stats(base_stats, player_index, false, args)

		modified_stats.projectile_spread += nb_projectile_effect * 0.15
		stats_every_x_shots[effect.value] = modified_stats

		# 撤销本轮临时效果，生成的属性对象保留计算结果。
		for sub_effect in effect.sub_effects:
			sub_effect.unapply(player_index)

	return stats_every_x_shots
