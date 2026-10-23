# 近战武器属性：扩展 WeaponStats，描述突刺/横扫、回程伤害和攻击类型交替。
# 本类负责属性与面板说明；实际攻击动作由 MeleeWeapon 和近战攻击行为执行。
class_name MeleeWeaponStats
extends WeaponStats

# 保留导出下拉选项及 MeleeWeaponStats.AttackType 的访问方式。
const AttackType = MeleeAttackType.AttackType

# 武器返回原位置的阶段是否也能造成伤害。
export(bool) var deal_dmg_on_return := false
# 初始攻击类型；数值来自共用枚举（突刺为 0，横扫为 1）。
export(AttackType) var attack_type = AttackType.THRUST
# 开启后由 MeleeWeapon 在攻击时切换下一次的突刺/横扫类型。
export(bool) var alternate_attack_type = false


# 启用交替攻击时追加本地化说明，否则不显示此条目。
func get_alternate_attack_type_text() -> String:
	return "" if !alternate_attack_type else "\n" + tr("ALTERNATES_ATTACK_TYPE")


# 启用回程伤害时追加本地化说明；是否实际造成伤害由近战攻击行为处理。
func get_deal_dmg_on_return_text() -> String:
	return "" if !deal_dmg_on_return else "\n" + tr("DEALS_DAMAGE_ON_RETURN")


# 计算基础面板攻击间隔（秒）：近战动作总时长 + 基础冷却帧数 × 倍率 / 60。
func get_base_cooldown_value(base_stats: Resource, multiplier: float) -> float:
	var player_index := -1 # isn't used for base stats
	# false 禁用玩家全局攻速；-1 只是未使用的玩家序号占位。
	var base_shooting_data = MeleeShootingData.new(base_stats, player_index, false)
	return base_shooting_data.get_shooting_total_duration() + base_stats.cooldown * multiplier / 60.0


# 计算当前面板攻击间隔（秒），动作时长使用当前属性和玩家攻速。
func get_cooldown_value(player_index: int, multiplier: float) -> float:
	var current_shooting_data = MeleeShootingData.new(self, player_index)
	# multiplier 只缩放冷却部分，不缩放动作时间；近战动作包含攻击、回程和后坐时间。
	return current_shooting_data.get_shooting_total_duration() + cooldown * multiplier / 60.0


# 提供范围说明中使用的近战类型文字，供父类 get_range_text() 调用。
func get_type_text() -> String:
	return tr("MELEE")


# 先序列化通用属性，再写入近战类型标记、回程伤害和攻击方式配置。
func serialize() -> Dictionary:
	var serialized = .serialize()

	# WeaponData 反序列化时用此标记选择 MeleeWeaponStats 子类。
	serialized.type = "melee"
	serialized.deal_dmg_on_return = deal_dmg_on_return
	serialized.attack_type = attack_type
	serialized.alternate_attack_type = alternate_attack_type

	return serialized


# 先恢复父类通用属性，再恢复近战字段；attack_type 保持整数形式以兼容已有资源和存档。
func deserialize_and_merge(serialized: Dictionary):
	.deserialize_and_merge(serialized)

	deal_dmg_on_return = serialized.deal_dmg_on_return
	attack_type = serialized.attack_type as int
	alternate_attack_type = serialized.alternate_attack_type
