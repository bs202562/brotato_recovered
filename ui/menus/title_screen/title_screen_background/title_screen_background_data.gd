class_name TitleScreenBackgroundData
extends Resource

export (String) var my_id = ""
export (int) var index_priority = 0
var my_id_hash: int = Keys.empty_hash
export (PackedScene) var scene
export (PackedScene) var logo_scene
export (bool) var last_update = false

export (Dictionary) var start_date = {
	"year": 2026, 
	"month": 5, 
	"day": 1
}

export (Dictionary) var end_date = {
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
	var duplication = .duplicate(subresources)

	if my_id_hash == Keys.empty_hash:
		my_id_hash = Keys.generate_hash(my_id)

	duplication.my_id_hash = self.my_id_hash
	return duplication

func is_available() -> bool:
	var current = OS.get_date()
	var currentValue = _date_to_int(current)
	var startValue = _date_to_int(start_date)
	var endValue = _date_to_int(end_date)
	return currentValue >= startValue and currentValue <= endValue


func _date_to_int(date: Dictionary) -> int:
	return date.year * 10000 + date.month * 100 + date.day
