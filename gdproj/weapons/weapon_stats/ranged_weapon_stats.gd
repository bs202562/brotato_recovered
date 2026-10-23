# 远程武器属性：扩展 WeaponStats，保存弹数、散射、穿透、弹射、弹速及子弹场景。
# 玩家加成由 WeaponService 合并，发射行为和子弹节点读取最终属性执行攻击。
class_name RangedWeaponStats
extends WeaponStats

# 一次发射的子弹数量；面板按单弹伤害 × 弹数展示。
export(int) var nb_projectiles := 1
# 散射角半宽（弧度），发射方向在武器朝向的 ±此值之间随机选择。
export(float) var projectile_spread := 0.0
# 穿透次数及每次穿透的伤害衰减比例；0.5 表示减少 50%。
export(int) var piercing := 0
export(float, 0, 1, 0.05) var piercing_dmg_reduction := 0.5
# 弹射次数及每次弹射的伤害衰减比例。
export(int) var bounce := 0
export(float, 0, 1, 0.05) var bounce_dmg_reduction := 0.5
# 是否允许弹射；WeaponService 计算属性时会将不允许弹射的武器弹射次数归零。
export(bool) var can_bounce = true
# 子弹移动速度；范围影响弹速的开关交由 WeaponService 计算。
export(int) var projectile_speed := 3000
export(bool) var increase_projectile_speed_with_range := false
# 自定义子弹场景，为 null 时 WeaponService 使用默认子弹；保持延迟配置以避免启动加载问题。
export(PackedScene) var projectile_scene = null # can't preload here, makes script bug at project launch
# 按场景路径生成的缓存标识；WeaponService.spawn_projectile 自定义子弹池使用场景实例 ID。
var projectile_pool_id: int = Keys.empty_hash


# 若被调用，根据自定义子弹场景路径生成池标识。
# 本类继承 Resource，不会像 Node 入树那样自动触发 _ready()。
func _ready() -> void:
	if projectile_scene != null:
		projectile_pool_id = Keys.generate_hash(projectile_scene.resource_path)


# 显示弹射次数和每次伤害衰减；没有弹射或不允许弹射时不显示。
func get_bouncing_text(base_stats: Resource) -> String:
	if bounce <= 0 or not can_bounce: return ""

	var a = get_signed_col_a(bounce, base_stats.bounce)
	# 伤害衰减越低越好，所以取负值进行增益/减益颜色比较。
	var aa = get_signed_col_a(-bounce_dmg_reduction, -base_stats.bounce_dmg_reduction)

	return "\n" + Text.text("PIERCING_FORMATTED", [get_col_a() + tr("BOUNCE") + col_b, a + str(bounce) + col_b, aa + str(round(bounce_dmg_reduction * 100.0)) + col_b])


# 显示穿透次数和每次伤害衰减；没有穿透时不显示。
func get_piercing_text(base_stats: Resource) -> String:
	if piercing <= 0: return ""

	var a = get_signed_col_a(piercing, base_stats.piercing)
	# 穿透衰减同样按“越低越好”着色，显示时换算为百分数。
	var aa = get_signed_col_a(-piercing_dmg_reduction, -base_stats.piercing_dmg_reduction)

	return "\n" + Text.text("PIERCING_FORMATTED", [get_col_a() + tr("PIERCING") + col_b, a + str(piercing) + col_b, aa + str(round(piercing_dmg_reduction * 100.0)) + col_b])


# 复用父类伤害说明逻辑，传入弹数，显示单弹伤害及多弹数量。
func get_damage_text(base_stats: Resource, player_index: int, effects: Array) -> String:
	return get_dmg_text_with_scaling_stats(base_stats, scaling_stats, nb_projectiles, player_index, effects)


# 计算基础面板攻击间隔（秒）：远程动作时长 + 基础冷却帧数 × 倍率 / 60。
func get_base_cooldown_value(base_stats: Resource, multiplier: float) -> float:
	var player_index := -1 # isn't used for base stats
	# false 禁用全局属性读取；-1 作为未使用的玩家序号占位。
	var base_shooting_data = RangedShootingData.new(base_stats, player_index, false)
	return base_shooting_data.get_shooting_total_duration() + base_stats.cooldown * multiplier / 60.0


# 计算当前面板攻击间隔（秒）；远程动作时长由 RangedShootingData 根据后坐时间计算。
func get_cooldown_value(player_index: int, multiplier: float) -> float:
	var current_shooting_data = RangedShootingData.new(self, player_index)
	# 远程动作时间为 recoil_duration 的两倍；multiplier 只作用于冷却帧数。
	return current_shooting_data.get_shooting_total_duration() + cooldown * multiplier / 60.0


# 提供范围说明中使用的远程类型文字，供父类 get_range_text() 调用。
func get_type_text() -> String:
	return tr("RANGED")


# 在通用属性字典上补充远程参数；自定义子弹场景保存为路径，不保存场景实例。
func serialize() -> Dictionary:
	var serialized = .serialize()

	# WeaponData 反序列化时用此标记选择 RangedWeaponStats 子类。
	serialized.type = "ranged"
	serialized.nb_projectiles = nb_projectiles
	serialized.projectile_spread = projectile_spread
	serialized.piercing = piercing
	serialized.piercing_dmg_reduction = piercing_dmg_reduction
	serialized.bounce = bounce
	serialized.bounce_dmg_reduction = bounce_dmg_reduction
	serialized.can_bounce = can_bounce
	serialized.projectile_speed = projectile_speed
	serialized.increase_projectile_speed_with_range = increase_projectile_speed_with_range

	if projectile_scene != null:
		serialized.projectile_scene = projectile_scene.resource_path

	return serialized


# 先恢复通用属性，再恢复远程参数；can_bounce 缺失时默认允许弹射，以兼容旧数据。
func deserialize_and_merge(serialized: Dictionary):
	.deserialize_and_merge(serialized)

	nb_projectiles = serialized.nb_projectiles as int
	projectile_spread = serialized.projectile_spread
	piercing = serialized.piercing as int
	piercing_dmg_reduction = serialized.piercing_dmg_reduction
	bounce = serialized.bounce as int
	bounce_dmg_reduction = serialized.bounce_dmg_reduction
	can_bounce = serialized.get("can_bounce", true)
	projectile_speed = serialized.projectile_speed as int
	increase_projectile_speed_with_range = serialized.increase_projectile_speed_with_range

	# 仅在存档包含路径时替换场景并更新哈希；缺少该键时保留当前场景。
	if serialized.has("projectile_scene"):
		projectile_scene = load(serialized.projectile_scene)
		projectile_pool_id = Keys.generate_hash(serialized.projectile_scene)
