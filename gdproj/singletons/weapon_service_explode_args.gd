class_name WeaponServiceExplodeArgs
extends Reference



var pos: Vector2
var damage: int
var scaling_stats: Array
var accuracy: float
var crit_chance: float
var crit_damage: float
var burning_data: BurningData
var from_player_index: int
var is_healing: bool = false
var ignored_objects: Array = []
var damage_tracking_key_hash: int = Keys.empty_hash
var from: Node = null

func Reset() -> void :
	pos = Vector2.ZERO
	damage = 0
	scaling_stats = []
	accuracy = 0.0
	crit_chance = 0.0
	crit_damage = 0.0
	burning_data = null
	from_player_index = 0
	is_healing = false
	ignored_objects.clear()
	damage_tracking_key_hash = Keys.empty_hash
	from = null
