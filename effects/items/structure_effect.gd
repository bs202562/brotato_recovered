class_name StructureEffect
extends Effect

@export var spawn_cooldown: int = -1
@export var scene: PackedScene = null
@export var stats: Resource = null
@export var effects: Array = [] # (Array, Resource)
@export var spawn_in_center: int = -1
@export var spawn_around_player: int = -1
@export var can_be_grouped: bool = true
@export var is_pet: bool = false

var is_cursed: bool = false
var _init_stats_args_structure :=  WeaponServiceInitStatsArgs.new()


static func get_id() -> String:
	return "structure"


func apply(player_index: int) -> void:
	RunData.get_player_effect(Keys.structures_hash, player_index).push_back(self)


func unapply(player_index: int) -> void:
	RunData.get_player_effect(Keys.structures_hash, player_index).erase(self)


func get_args(player_index: int) -> Array:
	var spawn_cd = WeaponService.apply_structure_attack_speed_effects(spawn_cooldown, player_index)
	var scaling_stats_names = WeaponService.get_scaling_stats_icon_text(stats.scaling_stats)

	_init_stats_args_structure.effects = effects

	var damage : int = 0
	if is_pet:
		var init_stats = WeaponService.init_structure_pet_stats(stats, player_index, _init_stats_args_structure)
		damage = init_stats.damage
	else:
		var init_stats  = WeaponService.init_structure_stats(stats, player_index, _init_stats_args_structure)
		damage = init_stats.damage

	return [str(value), str(spawn_cd), str(damage), scaling_stats_names]


func serialize() -> Dictionary:
	var serialized = super.serialize()

	serialized.spawn_cooldown = spawn_cooldown
	serialized.scene = scene.resource_path if scene else null
	serialized.stats = stats.serialize()

	serialized.effects = []
	for effect in effects:
		serialized.effects.push_back(effect.serialize())

	serialized.spawn_around_player = spawn_around_player
	serialized.spawn_in_center = spawn_in_center
	serialized.can_be_grouped = can_be_grouped
	serialized.is_pet = is_pet
	serialized.is_cursed = is_cursed

	return serialized


func deserialize_and_merge(serialized: Dictionary) -> void:
	super.deserialize_and_merge(serialized)

	spawn_cooldown = serialized.spawn_cooldown as int

	if serialized.scene:
		scene = load(serialized.scene)

	var struct_stats = RangedWeaponStats.new()
	struct_stats.deserialize_and_merge(serialized.stats)
	stats = struct_stats

	effects = []
	for serialized_effect in serialized.effects:
		for effect in ItemService.effects:
			if effect.get_id() == serialized_effect.effect_id:
				var instance = effect.new()
				instance.deserialize_and_merge(serialized_effect)
				effects.push_back(instance)
				break

	if serialized.has("spawn_around_player"):
		spawn_around_player = serialized.spawn_around_player

	if serialized.has("can_be_grouped"):
		can_be_grouped = serialized.can_be_grouped

	if serialized.has("is_pet"):
		is_pet = serialized.is_pet

	if serialized.has("spawn_in_center"):
		spawn_in_center = serialized.spawn_in_center

	if serialized.has("is_cursed"):
		is_cursed = serialized.is_cursed
