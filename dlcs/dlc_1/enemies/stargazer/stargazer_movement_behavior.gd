class_name StargazerMovementBehavior
extends TargetRandPosMovementBehavior

var lung: IronLung = null


func add_lung(p_lung: IronLung) -> void :
	_current_target = p_lung.global_position
	lung = p_lung


func get_new_target() -> Vector2:
	if not lung or not is_instance_valid(lung) or lung.dead or lung.is_full:
		return super.get_new_target()
	else:
		return lung.global_position
