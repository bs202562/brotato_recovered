class_name TitleScreenBackgroundData
extends Resource

@export var my_id: String = ""
@export var index_priority: int = 0
var my_id_hash: int = Keys.empty_hash
@export var scene: PackedScene
@export var logo_scene: PackedScene
@export var last_update: bool = false

@export var start_date: Dictionary = {
	"year": 2026, 
	"month": 5, 
	"day": 1
}

@export var end_date: Dictionary = {
	"year": 2026, 
	"month": 5, 
	"day": 25
}


func _init() -> void :
	
	
	if my_id_hash == Keys.empty_hash:
		call_deferred("_generate_hashes")


func _generate_hashes() -> void :
	my_id_hash = Keys.generate_hash(my_id)


func duplicate(subresources: = false) -> Resource:
	var duplication = super.duplicate(subresources)

	if my_id_hash == Keys.empty_hash:
		my_id_hash = Keys.generate_hash(my_id)

	duplication.my_id_hash = self.my_id_hash
	return duplication

func is_available() -> bool:
	var current = Time.get_date_dict_from_system()
	var currentValue = _date_to_int(current)
	var startValue = _date_to_int(start_date)
	var endValue = _date_to_int(end_date)
	return currentValue >= startValue and currentValue <= endValue


func _date_to_int(date: Dictionary) -> int:
	return date.year * 10000 + date.month * 100 + date.day
