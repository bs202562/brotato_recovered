# 武器物品资源：关联武器系列、场景、属性、套装和升级链，并保存伤害/效果追踪数据。
# WeaponStats 管理攻击数值；本类继承的名称、品质、价格与效果等由 ItemParentData 提供。
class_name WeaponData
extends ItemParentData

# 武器类别，与近战的突刺/横扫攻击类型是不同概念。
enum Type { MELEE, RANGED }

# 系列 ID 用于识别不同品质的同一种武器；父类 my_id 标识具体物品资源。
export(String) var weapon_id = ""
onready var weapon_id_hash = Keys.empty_hash
export(Type) var type := Type.MELEE
# 武器所属套装、实例化场景和基础属性资源。
export(Array, Resource) var sets
export(PackedScene) var scene = null
export(Resource) var stats = null
# 升级链的后继资源；previous_upgrade 指向前一等级。
export(Resource) var upgrades_into

var previous_upgrade : WeaponData

# 额外把此武器加入指定角色的初始武器选项。
export(Array, String) var add_to_chars_as_starting = []

# 波次伤害统计，以及效果累计值与本波新增值；波次切换/回滚逻辑会读取或重置这些字段。
var dmg_dealt_last_wave := 0
var tracked_value := 0
var tracked_value_added_this_wave := 0

# 复用属性计算参数，每次生成说明时填入本武器的套装和效果。
var _init_stats_args_data := WeaponServiceInitStatsArgs.new()


# 先生成父类物品 ID 哈希，再生成武器系列 ID 哈希。
func _generate_hashes() -> void:
	._generate_hashes()
	weapon_id_hash = Keys.generate_hash(weapon_id)


# 返回武器分类，供通用物品界面和业务逻辑识别。
func get_category() -> int:
	return Category.WEAPON



# 返回武器系列 ID 哈希；仅在缓存为 null 时重新生成。
func get_weapon_id_hash():
	if weapon_id_hash == null:
		weapon_id_hash = Keys.generate_hash(weapon_id)
	return weapon_id_hash

# 沿用父类资源复制逻辑，并显式保留 weapon_id_hash 缓存。
func duplicate(subresources := false) -> Resource:
	var duplication = .duplicate(subresources)
	duplication.weapon_id_hash = weapon_id_hash
	return duplication

# 根据玩家当前加成计算近战/远程属性，再用基础 stats 生成对比说明；可隐藏图鉴未解锁内容。
func get_weapon_stats_text(player_index: int, hide_if_non_unlock_in_codex : bool = false) -> String:
	if _is_locked_in_codex() and hide_if_non_unlock_in_codex : return ""
	_init_stats_args_data.sets = sets
	_init_stats_args_data.effects = effects
	var current_stats
	if type == Type.MELEE:
		current_stats = WeaponService.init_melee_stats(stats, player_index, _init_stats_args_data)
	else:
		current_stats = WeaponService.init_ranged_stats(stats, player_index, false, _init_stats_args_data)

	return current_stats.get_text(stats, player_index, effects)


# 取得父类效果说明，再按开关追加累计追踪数值。
func get_effects_text(player_index: int, with_tracking_text: bool = true) -> String:
	var text = .get_effects_text(player_index)

	if with_tracking_text and tracking_text != "":
		text += _get_tracking_text(player_index)

	return text

# 将 tracked_value 填入追踪说明模板，以次要文字颜色显示。
func _get_tracking_text(player_index: int) -> String:
	return "\n[color=#" + Utils.SECONDARY_FONT_COLOR.to_html() + "]" + Text.text(tracking_text.to_upper(), [str(tracked_value)]) + "[/color]"

# 累加总追踪值和本波新增值；默认增加 1。
func on_tracked_value_updated(value := 1) -> void:
	tracked_value += value
	tracked_value_added_this_wave += value

# 直接设置总追踪值及本波记录值；注意本波值也被赋为 value，而不是计算差额。
func on_tracked_value_set(value := 1) -> void:
	tracked_value = value
	tracked_value_added_this_wave = value


# 返回本地化武器名称，并按品质附加等级编号。
func get_name_text() -> String:
	var tier_number = ItemService.get_tier_number(tier)
	return tr(name) + (" " + tier_number if tier_number != "" else "")


# 沿用父类图鉴锁定判定，不额外改变武器解锁条件。
func _is_locked_in_codex() -> bool:
	return ._is_locked_in_codex()


# 沿当前武器、低级和高级升级链检查购买记录；任一等级购买过就不再显示剪影。
func _is_silhouette_in_codex() -> bool:
	var bought : int = _get_bought_times()
	if bought >= 1 : return false

	# 先向低品质遍历，再向高品质遍历；升级链应保持无环。
	var prev_weapon : WeaponData = self
	while is_instance_valid(prev_weapon.previous_upgrade) :
		bought += prev_weapon.previous_upgrade._get_bought_times()
		prev_weapon = prev_weapon.previous_upgrade
	if bought >= 1 : return false

	var next_weapon : WeaponData = self
	while is_instance_valid(next_weapon.upgrades_into) :
		bought += next_weapon.upgrades_into._get_bought_times()
		next_weapon = next_weapon.upgrades_into
	if bought >= 1 : return false

	return true


# 在父类物品字典上保存武器系列、属性、套装和追踪数据；部分数值按字符串保存。
func serialize() -> Dictionary:

	var serialized = .serialize()

	serialized.weapon_id = weapon_id
	serialized.type = str(type)
	serialized.stats = stats.serialize()
	serialized.dmg_dealt_last_wave = str(dmg_dealt_last_wave)
	serialized.tracked_value = str(tracked_value)
	serialized.tracked_value_added_this_wave = str(tracked_value_added_this_wave)
	serialized.add_to_chars_as_starting = add_to_chars_as_starting

	var serialized_sets = []

	for set in sets:
		serialized_sets.push_back(set.serialize())

	serialized.sets = serialized_sets

	return serialized


# 在现有资源上合并存档，恢复套装并根据 stats.type 创建相应的属性子类。
# 未写入该字典的场景和升级链引用由现有资源保留。
func deserialize_and_merge(serialized: Dictionary) -> void:
	.deserialize_and_merge(serialized)

	weapon_id = serialized.weapon_id
	weapon_id_hash = Keys.generate_hash(weapon_id)
	type = serialized.type as int
	dmg_dealt_last_wave = serialized.dmg_dealt_last_wave as int
	tracked_value = serialized.tracked_value as int
	tracked_value_added_this_wave = serialized.tracked_value_added_this_wave as int if "tracked_value_added_this_wave" in serialized else 0
	add_to_chars_as_starting = serialized.add_to_chars_as_starting if "add_to_chars_as_starting" in serialized else []

	var deserialized_sets = []

	# 通过已有套装 ID 找到资源后复制、合并，找不到的套装跳过。
	for serialized_set in serialized.sets:
		var set = ItemService.get_element_safe(ItemService.sets, serialized_set.my_id)
		if set != null:
			set = set.duplicate()
			set.deserialize_and_merge(serialized_set)
			deserialized_sets.push_back(set)

	sets = deserialized_sets

	# 根据序列化类型创建属性对象，随后由子类恢复近战或远程专属字段。
	stats = serialized.stats
	var deserialized_stats = WeaponStats.new()

	if serialized.stats.type == "ranged":
		deserialized_stats = RangedWeaponStats.new()
	elif serialized.stats.type == "melee":
		deserialized_stats = MeleeWeaponStats.new()

	deserialized_stats.deserialize_and_merge(serialized.stats)
	stats = deserialized_stats
