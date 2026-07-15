class_name WeaponServiceSpawnProjectileArgs
extends RefCounted

var knockback_direction: Vector2 = Vector2.ZERO
var deferred: bool = false
var effects: Array = []
var damage_tracking_key_hash: int = Keys.empty_hash
var from_player_index: int = - 1
