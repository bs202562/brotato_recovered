class_name StatData
extends Resource

@export var stat_name: String = ""
@export var icon: Resource = null
@export var small_icon: Resource = null
@export var is_primary_stat := false
@export var is_dlc_stat := false
@export var color_override := Color.BLACK

@export var reverse := false

var stat_hash: int = Keys.empty_hash

func _init() -> void :
	call_deferred("generate_hashes")

func generate_hashes() -> void :
	stat_hash = Keys.generate_hash(stat_name)
