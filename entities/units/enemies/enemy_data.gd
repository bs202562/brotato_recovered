class_name EnemyData
extends Resource

@export var my_id: String = ""
var my_id_hash: int = Keys.empty_hash
@export var zone_id: int = 0
@export var scene: PackedScene = null


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
