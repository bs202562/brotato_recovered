# 武器通用属性资源：保存攻击参数、生成面板说明，并提供序列化与复制。
# 近战/远程子类扩展专属属性；玩家加成主要由 WeaponService 计算。
class_name WeaponStats
extends Resource

# 基础冷却以帧计数，60 帧为 1 秒；最终显示间隔由子类计算。
export(int) var cooldown := 60 # ticks - we have 60 ticks per second
export(int) var damage := 1
# 精准度、暴击概率和生命窃取以比例保存；crit_damage 是伤害倍率。
export(float, 0.0, 1.0, 0.05) var accuracy = 1.0
export(float, 0.0, 1.0, 0.01) var crit_chance = 0.03
export(float) var crit_damage = 1.5
# 攻击范围上下界；min_range 为 0 时面板只显示最大范围。
export(int, 0, 10000) var min_range := 0
export(int, 0, 10000) var max_range := 150
# 正击退表示推开，负击退表示吸引；穿透比例用于绕过敌人的击退抗性。
export(int, -10000, 10000) var knockback := 0
export(float, 0.0, 1.0, 0.05) var knockback_piercing := 0.0 # Bypasses enemies' knockback_resistance stat
export(bool) var can_have_positive_knockback := true
export(bool) var can_have_negative_knockback := false
# 传给命中盒的效果缩放参数。
export(float, 0.0, 1.0, 0.1) var effect_scale := 1.0
# 每项为 [属性名或属性哈希, 换算系数]；初始化后统一转换为哈希。
export(Array, Array) var scaling_stats = [["stat_melee_damage", 1.0]]
export(float, 0, 1.0, 0.01) var lifesteal := 0.0
# 发射音效列表与音量修正（分贝）。
export(Array, Resource) var shooting_sounds
export(int) var sound_db_mod = -5
# 标记攻击是否用于治疗；可选贴图用于冷却期间的显示。
export(bool) var is_healing = false
export(Resource) var custom_on_cooldown_sprite = null
# 后坐位移及其持续时间（秒）。
export(int, 0, 1000) var recoil := 25
export(float, 0.01, 0.2) var recoil_duration := 0.1
# 周期性额外冷却：每 X 次攻击触发，-1 表示未启用；倍率由对应冷却逻辑使用。
export(int) var additional_cooldown_every_x_shots = -1
export(float) var additional_cooldown_multiplier = -1.0
# 传给命中盒的目标移动速度百分比修正。
export(int) var speed_percent_modifier := 0

# 运行时燃烧配置和武器自身攻速修正，由 WeaponService 等逻辑参与计算。
var burning_data: BurningData = BurningData.new()
var attack_speed_mod := 0.0 # modified in items for class bonus

var col_b = "[/color]"

# 初始化时把属性换算项转为哈希形式，并安排延迟初始化。
func _init() -> void:
	scaling_stats = Utils.convert_to_hash_array(scaling_stats.duplicate())
	call_deferred("_late_init")


# 资源导出字段加载后再次规范化换算列表，兼容资源里保存的字符串属性名。
func _late_init() -> void:
	scaling_stats = Utils.convert_to_hash_array(scaling_stats.duplicate())


# 生成武器面板的 BBCode 属性说明；用 base_stats 对比基础数值，子类补充各自专属条目。
func get_text(base_stats: Resource, player_index: int, effects: Array = []) -> String:
	var text = ""

	text += Text.text("DAMAGE_FORMATTED", [get_col_a() + tr("STAT_DAMAGE") + col_b, get_damage_text(base_stats, player_index, effects)])
	text += "\n" + Text.text("CRITICAL_FORMATTED", [get_col_a() + tr("CRITICAL") + col_b, get_crit_damage_text(base_stats), get_crit_chance_text(base_stats)])
	text += "\n" + Text.text("STAT_FORMATTED", [get_col_a() + tr("COOLDOWN") + col_b, get_cooldown_text(base_stats, player_index)])

	text += get_knockback_text(base_stats)
	text += get_range_text(base_stats)
	text += get_bouncing_text(base_stats)
	text += get_piercing_text(base_stats)
	text += get_lifesteal_text(base_stats)
	text += get_additional_cooldown_text(base_stats, player_index)
	text += get_deal_dmg_on_return_text()
	text += get_alternate_attack_type_text()

	return text


# 显示暴击伤害倍率（如 x1.5），并按相对基础值的变化着色。
func get_crit_damage_text(base_stats: Resource) -> String:
	var a = get_signed_col_a(crit_damage, base_stats.crit_damage)
	return a + "x" + str(crit_damage) + col_b


# 将暴击概率转为百分数显示，显示值最低为 0；此处不限制上限。
func get_crit_chance_text(base_stats: Resource) -> String:
	var a = get_signed_col_a(crit_chance, base_stats.crit_chance)
	return a + str(max(crit_chance * 100.0, 0)) + col_b


# 显示攻击间隔（秒）；冷却越短越好，因此对比颜色时取负值。
func get_cooldown_text(base_stats: Resource, player_index: int, multiplier: float = 1.0) -> String:
	var cd = get_cooldown_value(player_index, multiplier)
	var base_cd = get_base_cooldown_value(base_stats, multiplier)
	var a = get_signed_col_a(-cd, -base_cd)

	# 小于 0.2 秒时显示到毫秒，否则显示到百分之一秒。
	var step = 0.001 if cd < 0.2 else 0.01
	return a + str(stepify(cd, step)) + "s" + col_b


# 显示每隔指定攻击次数触发的额外冷却；次数为 -1 时不显示。
func get_additional_cooldown_text(base_stats: Resource, player_index: int) -> String:
	if additional_cooldown_every_x_shots == -1:
		return ""
	else:
		return "\n" + Text.text("ADDITIONAL_COOLDOWN_EVERY_X_SHOTS", [get_cooldown_text(base_stats, player_index, additional_cooldown_multiplier), str(additional_cooldown_every_x_shots)])


# 当前攻击间隔的子类扩展点；基类返回占位值，由近战/远程实现具体计算。
func get_cooldown_value(_player_index: int, _multiplier: float) -> float:
	return 0.0


# 基础攻击间隔的子类扩展点，用于与当前值比较；基类返回占位值。
func get_base_cooldown_value(_base_stats: Resource, _multiplier: float) -> float:
	return 0.0


# 生成击退说明，零击退不显示；仅允许负击退的武器按吸引强度反向比较颜色。
func get_knockback_text(base_stats: Resource) -> String:
	if knockback == 0: return ""

	var a = get_signed_col_a(knockback, base_stats.knockback)

	if base_stats.can_have_negative_knockback and not base_stats.can_have_positive_knockback:
		a = get_signed_col_a(base_stats.knockback, knockback)

	return "\n" + Text.text("STAT_FORMATTED", [get_col_a() + tr("KNOCKBACK") + col_b, a + str(knockback)]) + col_b


# 显示最大范围或最小～最大范围；最大范围变化时附带基础范围，并显示子类类型说明。
func get_range_text(base_stats: Resource) -> String:
	var type_text = get_type_text()
	var a = get_signed_col_a(max_range, base_stats.max_range)

	var range_text = str(max_range) if min_range == 0 else str(min_range) + "-" + str(max_range)
	var base_range_text = str(base_stats.max_range) if base_stats.min_range == 0 else str(base_stats.min_range) + "-" + str(base_stats.max_range)

	var text = a + range_text + col_b

	if max_range != base_stats.max_range:
		text += get_init_a() + base_range_text + col_b

	return "\n" + Text.text("RANGE_FORMATTED", [get_col_a() + tr("STAT_RANGE") + col_b, text, type_text])


# 生成默认单次命中的伤害说明；远程子类可覆盖为多弹数显示。
func get_damage_text(base_stats: Resource, player_index: int, effects: Array) -> String:
	return get_dmg_text_with_scaling_stats(base_stats, scaling_stats, 1, player_index, effects)


# 生成伤害、弹数和属性换算图标；生命相关伤害效果在显示时额外计算，不改写 damage。
func get_dmg_text_with_scaling_stats(base_stats: Resource, p_scaling_stats: Array, nb_projectiles: int, player_index: int, effects: Array) -> String:

	var displayed_damage = damage

	for effect in effects:
		if effect is PlayerHealthStatEffect and effect.key == "stat_damage":
			displayed_damage += effect.get_bonus_damage(player_index)

	var a = get_signed_col_a(displayed_damage, base_stats.damage)
	var dmg_text = a + str(displayed_damage) + col_b

	var text = dmg_text if nb_projectiles == 1 else dmg_text + "x" + str(nb_projectiles)

	if displayed_damage != base_stats.damage:
		var initial_dmg_text = str(base_stats.damage) if nb_projectiles == 1 else str(base_stats.damage) + "x" + str(nb_projectiles)
		text += get_init_a() + initial_dmg_text + col_b

	text += " (" + WeaponService.get_scaling_stats_icon_text(p_scaling_stats) + ")"

	return text


# 弹射说明扩展点，基类不显示，由适用的子类实现。
func get_bouncing_text(_base_stats: Resource) -> String:
	return ""


# 穿透说明扩展点，基类不显示，由适用的子类实现。
func get_piercing_text(_base_stats: Resource) -> String:
	return ""


# 近战/远程类型说明扩展点，基类返回空字符串。
func get_type_text() -> String:
	return ""


# 交替攻击类型说明扩展点，由近战属性子类实现。
func get_alternate_attack_type_text() -> String:
	return ""


# 回程伤害说明扩展点，由近战属性子类实现。
func get_deal_dmg_on_return_text() -> String:
	return ""


# 显示正数生命窃取概率，转换为百分数并四舍五入。
func get_lifesteal_text(base_stats: Resource) -> String:
	if lifesteal <= 0.0: return ""
	var a = get_signed_col_a(lifesteal, base_stats.lifesteal)
	return "\n" + Text.text("STAT_FORMATTED", [get_col_a() + tr("LIFESTEAL") + col_b, a + str(round(lifesteal * 100.0))]) + "%" + col_b


# 生成精准度百分比说明；当前显示值限制在 0～100%，变化时附带基础值。
func get_accuracy_text(base_stats: Resource) -> String:
	var a = get_signed_col_a(accuracy, base_stats.accuracy)
	var text = a + str(clamp(accuracy * 100.0, 0, 100)) + "%" + col_b

	if accuracy != base_stats.accuracy:
		text += get_init_a() + str(base_stats.accuracy * 100.0) + "%" + col_b

	return text


# 返回精准度，提供可由子类覆盖的读取入口。
func get_accuracy() -> float:
	return accuracy


# 返回数值变化对应的 BBCode 起始颜色：增加、相等、减少分别使用正向、白色、负向颜色。
func get_signed_col_a(value: float, base_value: float) -> String:
	var col_pos_a = "[color=#"+ ProgressData.settings.color_positive +"]"
	var col_neutral_a = "[color=white]"
	var col_neg_a = "[color=#"+ ProgressData.settings.color_negative +"]"
	if value > base_value: return col_pos_a
	elif value == base_value: return col_neutral_a
	else: return col_neg_a


# 返回属性名称使用的 BBCode 起始颜色。
func get_col_a() -> String:

	return "[color=#eae2b0]"


# 返回基础数值前的分隔符及灰色 BBCode 标签。
func get_init_a() -> String:

	return " [color=#555555]| "


# 导出通用属性字典，音效与可选贴图保存为资源路径；子类可继续增加专属字段。
# 这是显式列出的存档字段，不会自动保存此对象的全部成员。
func serialize() -> Dictionary:

	var shooting_sounds_paths = []

	for shooting_sound in shooting_sounds:
		shooting_sounds_paths.push_back(shooting_sound.resource_path)

	var serialized = {
		"type": "base",
		"cooldown": cooldown,
		"damage": damage,
		"accuracy": accuracy,
		"crit_chance": crit_chance,
		"crit_damage": crit_damage,
		"min_range": min_range,
		"max_range": max_range,
		"knockback": knockback,
		"knockback_piercing": knockback_piercing,
		"can_have_positive_knockback": can_have_positive_knockback,
		"can_have_negative_knockback": can_have_negative_knockback,
		"effect_scale": effect_scale,
		"scaling_stats": scaling_stats,
		"lifesteal": lifesteal,
		"shooting_sounds": shooting_sounds_paths,
		"sound_db_mod": sound_db_mod,
		"is_healing": is_healing,
		"recoil": recoil,
		"recoil_duration": recoil_duration,
		"additional_cooldown_every_x_shots": additional_cooldown_every_x_shots,
		"additional_cooldown_multiplier": additional_cooldown_multiplier
	}

	if custom_on_cooldown_sprite != null:
		serialized.custom_on_cooldown_sprite = custom_on_cooldown_sprite.resource_path

	return serialized


# 把字典中的通用属性合并回当前资源，按路径加载音效，并为部分旧存档字段提供默认值。
func deserialize_and_merge(serialized: Dictionary):

	shooting_sounds = []

	for sound_path in serialized.shooting_sounds:
		var sound = load(sound_path)
		if sound != null:
			shooting_sounds.push_back(sound)

	cooldown = serialized.cooldown as int
	damage = serialized.damage as int
	accuracy = serialized.accuracy
	crit_chance = serialized.crit_chance
	crit_damage = serialized.crit_damage
	min_range = serialized.min_range as int
	max_range = serialized.max_range as int
	knockback = serialized.knockback as int
	# 兼容不含击退穿透或正负击退限制字段的旧数据。
	knockback_piercing = serialized.knockback_piercing if "knockback_piercing" in serialized else 0.0
	can_have_positive_knockback = serialized.can_have_positive_knockback if "can_have_positive_knockback" in serialized else true
	can_have_negative_knockback = serialized.can_have_negative_knockback if "can_have_negative_knockback" in serialized else false
	effect_scale = serialized.effect_scale
	scaling_stats = Utils.convert_to_hash_array(serialized.scaling_stats)
	lifesteal = serialized.lifesteal
	sound_db_mod = serialized.sound_db_mod as int
	is_healing = serialized.is_healing
	recoil = serialized.recoil as int
	recoil_duration = serialized.recoil_duration
	additional_cooldown_every_x_shots = serialized.additional_cooldown_every_x_shots as int
	additional_cooldown_multiplier = serialized.additional_cooldown_multiplier

	if serialized.has("custom_on_cooldown_sprite"):
		custom_on_cooldown_sprite = load(serialized.custom_on_cooldown_sprite)


# 调用 Resource 的复制逻辑后，另行浅复制 scaling_stats 外层数组；内部条目不因此自动深复制。
func duplicate(subresources := false) -> Resource:
	var duplication = .duplicate(subresources)
	duplication.scaling_stats = self.scaling_stats.duplicate()

	return duplication
