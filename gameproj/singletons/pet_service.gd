extends Node

var _targets_by_pet: = {}

func reset():
	_targets_by_pet.clear()

func add_target_for_pet(target: Node2D, pet_id: int) -> void :
	if _targets_by_pet.has(pet_id):
		_targets_by_pet[pet_id].push_back(target)
	else:
		_targets_by_pet[pet_id] = [target]

func remove_target_for_pet(target: Node2D, pet_id: int) -> void :
	if _targets_by_pet.has(pet_id):
		_targets_by_pet[pet_id].erase(target)

func has_target_for_pet(target: Node2D, pet_id: int) -> bool:
	if _targets_by_pet.has(pet_id):
		return _targets_by_pet[pet_id].has(target)
	return false
