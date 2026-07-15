class_name ChallengeData
extends ItemParentData

enum RewardType { ITEM, WEAPON, ZONE, STARTING_WEAPON, CONSUMABLE, UPGRADE, CHARACTER, DIFFICULTY, SYSTEM }

@export var description: String = ""
@export var reward_type: int = RewardType.ITEM # 4.x 移植: 枚举与全局类同名，统一 int
@export var reward: Resource
@export var number: int = 0
@export var stat: String = ""
@export var additional_args: Array

var stat_hash: int = Keys.empty_hash


func _generate_hashes() -> void:
	super._generate_hashes()
	stat_hash = Keys.generate_hash(stat)


func get_reward_type_string() -> String:
	match reward_type:
		RewardType.ITEM:
			return "ITEM"
		RewardType.WEAPON:
			return "WEAPON"
		RewardType.ZONE:
			return "ZONE"
		RewardType.STARTING_WEAPON:
			return "STARTING_WEAPON"
		RewardType.CONSUMABLE:
			return "CONSUMABLE"
		RewardType.UPGRADE:
			return "UPGRADE"
		RewardType.CHARACTER:
			return "CHARACTER"
		RewardType.DIFFICULTY:
			return "DIFFICULTY"
		RewardType.SYSTEM:
			return "SYSTEM"
	return ""


func get_category() -> int:
	return Category.CHALLENGE


func get_name_text() -> String:
	return Text.text(name, [str(number)])


func get_description_text() -> String:
	return Text.text(description, _get_desc_args())


func _get_desc_args() -> Array:
	if name.begins_with("CHARACTER_"):
		return [Text.text(name)]
	else:
		var args = [str(value), tr(stat.to_upper())]

		for arg in additional_args:
			args.push_back(tr(str(arg)))

		return args
