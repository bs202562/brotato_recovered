class_name Stats
extends Resource

enum Tier{COMMON, UNCOMMON, RARE, LEGENDARY}

@export var icon: Texture2D
@export var health: int = 1
@export var health_increase_each_wave: float = 1.0
@export var speed: int = 300
@export var speed_randomization: int = 0
@export var damage: int = 1
@export var damage_increase_each_wave: float = 1.0
@export var attack_cd: float = 30.0
@export var value: int = 1
@export var knockback_resistance = 0.0 # (float, 0.0, 1.0, 0.05)
@export var gold_spread: int = 0
@export var can_drop_consumables: bool = true
@export var always_drop_consumables: bool = false
@export var base_drop_chance = 0.01 # (float, 0.0, 1.0, 0.01)
@export var legendary_drop_chance = 0.01 # (float, 0.0, 1.0, 0.01)
@export var item_drop_chance = 0.01 # (float, 0.0, 1.0, 0.01)
@export var min_consumable_tier: int = Tier.COMMON # 4.x 移植: 原为 Tier 枚举，与全局 Tier 类同名冲突，统一用 int
@export var max_consumable_tier: int = Tier.COMMON
@export var armor: int = 0
@export var armor_increase_each_wave: float = 0.0
@export var generate_blood := true


func get_base_damage(wave: int) -> float:
	return damage + damage_increase_each_wave * (wave - 1)


func get_base_health(wave: int) -> int:
	return health + health_increase_each_wave * (wave - 1)
