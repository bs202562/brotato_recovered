# 敌人公共层：Entity → Unit → Enemy → 各种具体敌人。
# 增加目标选择、攻击行为、敌人数值修正、魅惑和击杀相关效果。
# 首次生成走 init，对象池复用走 respawn；攻击动作委托给 AttackBehavior。
# 通用碰撞受伤逻辑在 Unit，本文件补充敌人特有的伤害与状态规则。
class_name Enemy
extends Unit

signal charmed(enemy)
signal healed(enemy)
signal wanted_to_spawn_an_enemy(enemy_scene, at_position, source, charmed_by)
signal state_changed(enemy)

export (String) var enemy_id: = ""
export (bool) var is_loot: = false
export (bool) var can_be_cursed = true
export (bool) var can_be_charmed = true
export (bool) var to_be_removed_in_priority = false

var enemy_id_hash: = Keys.empty_hash;


# 普通敌人不属于玩家，用 -1 表示；魅惑归属从效果行为单独读取。
const player_index = - 1

# 多目标时每 0.25 秒重新选择，避免每帧遍历候选目标。
const UPDATE_TARGET_DELAY: float = 0.25
var update_target_timer: float = 0.0
var current_target = null

var source_spawner = null
var _idle_playback_speed = rand_range(1, 3)
var _current_attack_cd: float
var _current_attack_behavior: AttackBehavior
var _all_attack_behaviors: Array = []
var _all_additional_projectiles: Array = []
var shoot_animation_name: String = "shoot"

onready var _attack_behavior = $AttackBehavior
onready var _hitbox = $Hitbox

var _take_damage_args: = TakeDamageArgs.new(0)


# 绑定默认攻击行为、动画完成事件和接触 Hitbox 的攻击来源。
func _ready() -> void :
	_current_attack_behavior = _attack_behavior
	_animation_player.playback_speed = _idle_playback_speed
	_hitbox.from = self
	enemy_id_hash = Keys.generate_hash(enemy_id)
	_all_attack_behaviors.push_back(_attack_behavior)

	var _e = _animation_player.connect("animation_finished", self, "_on_AnimationPlayer_animation_finished")


# 首次出生：调用 Unit 初始化，再计算属性、挂载效果、初始化攻击并选目标。
func init(zone_min_pos: Vector2, zone_max_pos: Vector2, p_players_ref: Array = [], entity_spawner_ref = null) -> void :
	.init(zone_min_pos, zone_max_pos, p_players_ref, entity_spawner_ref)

	init_current_stats()
	init_effect_behaviors()

	var factor = RunData.sum_all_player_effects(Keys.stronger_loot_aliens_on_kill_hash)
	if is_loot and factor > 0:
		var bonus_health = factor * RunData.loot_aliens_killed_this_run
		reset_health_stat(bonus_health)

	if DebugService.nullify_enemy_speed:
		stats.speed = - 1000
		current_stats.speed = - 1000

	_hitbox.connect("hit_something", self, "_on_hit_something")
	_hitbox.damage = current_stats.damage

	_attack_behavior.init(self)

	update_target()


# 复用敌人：恢复父类状态、重置攻击和属性、重新挂载效果并开启接触伤害。
func respawn() -> void :
	.respawn()

	_attack_behavior.reset()
	init_current_stats()
	init_effect_behaviors()

	var factor = RunData.sum_all_player_effects(Keys.stronger_loot_aliens_on_kill_hash)
	if is_loot and factor > 0:
		var bonus_health = factor * RunData.loot_aliens_killed_this_run
		reset_health_stat(bonus_health)

	_hitbox.damage = current_stats.damage
	_hitbox.enable()
	update_target()


# 定期重选目标、更新攻击冷却并驱动攻击行为。
# 击退速度占主导时关闭接触 Hitbox，结束后恢复。
func _physics_process(delta: float) -> void :
	if dead:
		return

	var potential_target_count = players_ref.size() + _entity_spawner_ref.targetable_pets.size()
	if potential_target_count > 1 or collision_layer == Utils.PETS_BIT:
		update_target_timer += delta
		if update_target_timer >= UPDATE_TARGET_DELAY:
			update_target_timer = 0.0
			update_target()

	# 冷却使用以 60 帧为基准的计数单位，delta 本身仍以秒计。
	_current_attack_cd = max(_current_attack_cd - 60 * delta, 0)
	var is_being_knocked_back = get_knockback_value().length_squared() > get_move_input().length_squared()

	if not _hitbox.is_disabled() and is_being_knocked_back:
		_hitbox.disable()
	elif _hitbox.is_disabled() and not is_being_knocked_back:
		_hitbox.enable()

	_current_attack_behavior.physics_process(delta)


# 拉近敌人时临时降低接触伤害，约一秒后恢复，降低后至少保留 1 点。
func set_hitbox_damage_modifier() -> void :
	_hitbox_damage_modifier = min(_hitbox.damage - 1, int(current_stats.damage * 0.9)) as int
	_hitbox.damage = _hitbox.damage - _hitbox_damage_modifier
	var timer: SceneTreeTimer = get_tree().create_timer(1.0, false)
	var _e = timer.connect("timeout", self, "reset_hitbox_damage_modifier")


# 加回暂时扣除的接触伤害；死亡后不再恢复。
func reset_hitbox_damage_modifier() -> void :

	if dead:
		return

	if _hitbox_damage_modifier > 0:
		_hitbox.damage = _hitbox.damage + _hitbox_damage_modifier
	_hitbox_damage_modifier = 0


# 重算接触伤害，同步所有已注册攻击行为与额外弹体的伤害。
func reset_damage_stat(percent_modifier: int = 0) -> void :
	.reset_damage_stat(percent_modifier)
	_hitbox.damage = current_stats.damage
	_hitbox_damage_modifier = 0

	for attack_behavior in _all_attack_behaviors:
		set_attack_behavior_damage(attack_behavior, percent_modifier)

	for additional_projectile in _all_additional_projectiles:
		if additional_projectile and is_instance_valid(additional_projectile):
			set_additional_projectile_damage(additional_projectile, percent_modifier)


# 登记需要同步伤害的攻击行为，并立即初始化伤害。
func register_attack_behavior(p_attack_behavior: AttackBehavior) -> void :
	_all_attack_behaviors.push_back(p_attack_behavior)
	set_attack_behavior_damage(p_attack_behavior)


# 射击行为伤害先按波次成长，再应用 EntityService 的全局修正。
func set_attack_behavior_damage(p_attack_behavior: AttackBehavior, percent_modifier: int = 0) -> void :
	if p_attack_behavior is ShootingAttackBehavior:
		var base_damage = p_attack_behavior.damage + p_attack_behavior.damage_increase_each_wave * (RunData.current_wave - 1)
		p_attack_behavior.projectile_damage = EntityService.get_final_enemy_damage(base_damage, percent_modifier)


# 登记需要同步伤害的额外弹体，忽略无效实例。
func register_additional_projectile(p_additional_projectile: EnemyProjectile) -> void :

	if not p_additional_projectile or not is_instance_valid(p_additional_projectile):
		return

	_all_additional_projectiles.push_back(p_additional_projectile)
	set_additional_projectile_damage(p_additional_projectile)


# 按额外弹体的基础伤害与波次成长重新计算最终伤害。
func set_additional_projectile_damage(p_additional_projectile: EnemyProjectile, percent_modifier: int = 0) -> void :
	var base_damage = p_additional_projectile.damage + p_additional_projectile.damage_increase_each_wave * (RunData.current_wave - 1)
	p_additional_projectile.set_damage(EntityService.get_final_enemy_damage(base_damage, percent_modifier))


# 实例化当前启用的敌人效果行为；断言要求旧行为已清理，避免重复添加。
func init_effect_behaviors() -> void :
	assert (effect_behaviors.get_child_count() == 0, "init_effect_behaviors should only be called once")
	for effect_behavior_data in EffectBehaviorService.active_enemy_effect_behavior_data:
		effect_behaviors.add_child(effect_behavior_data.scene.instance().init(self))


# 按距离平方选择存活的宠物或玩家，再让效果行为调整目标。
# 监听目标死亡以立即重选；多目标的周期性重选在 _physics_process 中节流。
func update_target() -> void :
	var min_dist_squared: int = Utils.LARGE_NUMBER

	for pet in _entity_spawner_ref.targetable_pets:
		if pet.dead:
			continue
		var dist_squared = global_position.distance_squared_to(pet.global_position)
		if dist_squared < min_dist_squared:
			min_dist_squared = dist_squared
			current_target = pet

	for player in players_ref:
		if player.dead:
			continue
		var dist_squared = global_position.distance_squared_to(player.global_position)
		if dist_squared < min_dist_squared:
			min_dist_squared = dist_squared
			current_target = player

	for effect_behavior in effect_behaviors.get_children():
		effect_behavior.update_target()

	if not current_target.is_connected("died", self, "_on_target_died"):
		var _error_died = current_target.connect("died", self, "_on_target_died")


# 目标死亡后立即重选。
func _on_target_died(_entity: Entity, _die_args: Entity.DieArgs) -> void :
	update_target()


# 当前目标被魅惑时重新评估追击目标。
func _on_enemy_charmed(enemy: Enemy):
	if current_target == enemy:
		update_target()


# 转交父层属性更新流程，再同步接触 Hitbox 的伤害。
func update_stats(hp_coef: float, damage_coef: float, speed_coef: float) -> void :
	.update_stats(hp_coef, damage_coef, speed_coef)
	_hitbox.damage = current_stats.damage


# 在 Unit 的速度修正上增加战利品敌人的专属速度效果。
func get_speed_effect_mods(player_index: int) -> int:
	var speed_from_loot = RunData.get_player_effect(Keys.loot_alien_speed_hash, player_index) if is_loot else 0
	return .get_speed_effect_mods(player_index) + speed_from_loot


# 委托当前攻击行为开始攻击准备。
func start_shoot() -> void :
	_current_attack_behavior.start_shoot()


# 委托当前攻击行为执行攻击；射击行为会在其中生成子弹。
func shoot() -> void :
	_current_attack_behavior.shoot()


# 先执行 Unit / Entity 的死亡流程并关闭接触伤害，再处理击杀距离、过量伤害爆炸等。
# 清场时跳过下方正常击杀相关逻辑。
func die(args: = Utils.default_die_args) -> void :
	.die(args)
	_hitbox.disable()
	source_spawner = null
	# 清场不算普通击杀，不继续触发下方挑战、爆炸和战利品敌人统计。
	if args.cleaning_up:
		return

	if args.enemy_killed_by_player and args.killed_by_player_index >= 0 and args.killed_by_player_index < players_ref.size() and is_instance_valid(players_ref[args.killed_by_player_index]):
		var challenge: ChallengeData = ChallengeService.get_chal(ChallengeService.chal_cautious_hash)
		if challenge:
			var distance_to_killer: float = global_position.distance_squared_to(players_ref[args.killed_by_player_index].global_position)
			if distance_to_killer >= pow(challenge.additional_args[0], 2):
				ProgressData.increment_stat("enemies_killed_far_away")

		for explode_on_overkill in RunData.get_player_effect(Keys.explode_on_overkill_hash, args.killed_by_player_index):
			if args.killing_blow_dmg_value >= max_stats.health * (explode_on_overkill.value / 100.0):
				
				RunData.handle_explode_effect(Keys.explode_on_overkill_hash, global_position, args.killed_by_player_index)
				break

	if is_loot:
		RunData.loot_aliens_killed_this_run += 1


# 施加攻击者提供的命中减速；调试模式可额外触发巨额伤害。
func _on_hurt(hitbox: Hitbox) -> void :
	var from_player_index: int = RunData.DUMMY_PLAYER_INDEX

	if is_instance_valid(hitbox.from) and hitbox.from.player_index != - 1:
		from_player_index = hitbox.from.player_index

	var remove_speed_data = RunData.get_remove_speed_data(from_player_index)
	if remove_speed_data.value > 0 and current_stats.speed > max_stats.speed * (1 - (remove_speed_data.max_value / 100.0)):
		current_stats.speed -= (max_stats.speed * (remove_speed_data.value / 100.0))

	if DebugService.one_shot_enemies:
		_take_damage_args._init(from_player_index, null)
		var _damage_taken = take_damage(Utils.LARGE_NUMBER, _take_damage_args)


# 复用 Unit 的受伤结算，再用完整伤害检查过量伤害挑战。
func take_damage(value: int, args: TakeDamageArgs) -> Array:
	var damage_taken: = .take_damage(value, args)

	
	ChallengeService.try_complete_challenge(ChallengeService.chal_overkill_hash, damage_taken[0])
	return damage_taken


# 在父类结果上追加基于敌人当前生命的伤害，包括暴击和燃烧道具效果。
# 追加伤害受无尽模式系数影响，并更新对应道具统计。
func get_damage_value(dmg_value: int, from_player_index: int, armor_applied: = true, dodgeable: = true, is_crit: = false, hitbox: Hitbox = null, is_burning: = false) -> GetDamageValueResult:
	var dmg_value_result = .get_damage_value(dmg_value, from_player_index, armor_applied, dodgeable, is_crit, hitbox)

	
	var actual_dmg_value = dmg_value_result.value
	var endless_factor = RunData.get_endless_factor() * 0.2

	if from_player_index >= 0 and hitbox:
		for effect in hitbox.effects:
			if effect.key_hash == Keys.bonus_current_health_damage_hash:
				var bonus_modifier = effect.value / _get_health_effect_percent_factor()
				var bonus_dmg = int((current_stats.health * bonus_modifier) / max(1.0, endless_factor))
				actual_dmg_value += bonus_dmg

	var giant_crit_damage_effect = RunData.get_player_effect(Keys.giant_crit_damage_hash, from_player_index)
	if giant_crit_damage_effect is Array:
		if is_crit and from_player_index >= 0 and giant_crit_damage_effect.size() > 0:
			for giant_dmg_value_pair in giant_crit_damage_effect:
				var giant_crit_damage_modifier = giant_dmg_value_pair[0] / _get_health_effect_percent_factor()
				var giant_bonus: = int((current_stats.health * giant_crit_damage_modifier) / max(1.0, endless_factor))
				actual_dmg_value += giant_bonus

				var dmg_dealt: = clamp(giant_bonus, 0, max(0, current_stats.health - dmg_value))
				RunData.add_tracked_value(from_player_index, Keys.item_giant_belt_hash, dmg_dealt)

	if is_burning and _burning_player_index >= 0 and RunData.get_player_effect(Keys.burning_enemy_hp_percent_damage_hash, _burning_player_index).size() > 0:
		var enemy_hp_percent_damage = 0

		for dmg_pair in RunData.get_player_effect(Keys.burning_enemy_hp_percent_damage_hash, _burning_player_index):
			enemy_hp_percent_damage += dmg_pair[0] / _get_health_effect_percent_factor()

		var greek_fire_bonus: = int((current_stats.health * enemy_hp_percent_damage) / max(1.0, endless_factor))
		RunData.add_tracked_value(_burning_player_index, Keys.item_greek_fire_hash, greek_fire_bonus)
		actual_dmg_value += greek_fire_bonus

	dmg_value_result.value = actual_dmg_value

	return dmg_value_result


# 保存基础强化状态后，重算敌人生命、伤害和速度。
func boost(boost_args: BoostArgs) -> void :
	if not can_be_boosted:
		return

	.boost(boost_args)
	reset_health_stat(boost_args.hp_boost)
	reset_damage_stat(boost_args.damage_boost)
	reset_speed_stat(boost_args.speed_boost)


# 接触命中后加入短暂减速，速度随后逐步恢复。
func _on_hit_something(_thing_hit: Node, _damage_dealt: int) -> void :
	add_decaying_speed(int( - max(200, current_stats.speed * 0.8)), false)


# 非待机/死亡动画结束后恢复待机，再通知当前攻击行为动画完成。
func _on_AnimationPlayer_animation_finished(anim_name: String) -> void :
	if anim_name != "idle" and anim_name != "death":
		_animation_player.play("idle")
		_animation_player.playback_speed = _idle_playback_speed

	_current_attack_behavior.animation_finished(anim_name)


# 转发生成敌人的请求，并附带本敌人作为来源及魅惑玩家归属。
func _on_AttackBehavior_wanted_to_spawn_an_enemy(enemy_scene: PackedScene, at_position: Vector2) -> void :
	emit_signal("wanted_to_spawn_an_enemy", enemy_scene, at_position, self, get_charmed_by_player_index())


# 从支持魅惑的效果行为中读取归属，没有则返回 -1。
func get_charmed_by_player_index() -> int:
	for effect_behavior in effect_behaviors.get_children():
		if "charmed" in effect_behavior and effect_behavior.charmed:
			return effect_behavior.charmed_by_player_index
	return - 1


# 把魅惑请求交给支持该能力的效果行为。
func set_charmed(from_player_index: int) -> void :
	for effect_behavior in effect_behaviors.get_children():
		if "charmed" in effect_behavior:
			effect_behavior.charm(from_player_index)


# 记录产生本敌人的来源；死亡时清除。
func set_source(source) -> void :
	source_spawner = source


# 检查当前动画是否为普通或魅惑射击。
func is_playing_shoot_animation() -> bool:
	return _animation_player.current_animation == "shoot" or _animation_player.current_animation == "shoot_charmed"


# 检查传入动画名是否为射击动画。
func is_shooting_anim(anim_name: String) -> bool:
	return anim_name == "shoot" or anim_name == "shoot_charmed"
