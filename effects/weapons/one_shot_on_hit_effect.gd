class_name OneShotOnHitEffect
extends NullEffect

@export var sound_one_shot: AudioStream
@export var particles_one_shot: PackedScene

static func get_id() -> String:
	return "weapon_one_shot_on_hit"
