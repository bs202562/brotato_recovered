class_name StatData
extends Resource

export (String) var stat_name = ""
export (Resource) var icon = null
export (Resource) var small_icon = null
export (bool) var is_primary_stat: = false
export (bool) var is_dlc_stat: = false
export (Color) var color_override: = Color.black

export (bool) var reverse: = false

var stat_hash: int = Keys.empty_hash

func _init() -> void :
	call_deferred("generate_hashes")

func generate_hashes() -> void :
	stat_hash = Keys.generate_hash(stat_name)
