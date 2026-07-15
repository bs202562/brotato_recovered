class_name FollowTargetMovementBehavior
extends MovementBehavior

@export var stop_close_to_target := false
@export var distance_to_target := 30

var _target_player: = false

func get_movement() -> Vector2:
	if stop_close_to_target and _target_player and _parent.global_position.distance_squared_to(_parent.current_target.global_position) < distance_to_target * distance_to_target:
		return Vector2.ZERO

	var value = get_target_position() - _parent.global_position
	return value


func get_target_position():
	if not is_instance_valid(_parent.current_target):
		return global_position
	return _parent.current_target.global_position


func _on_TargetBehavior_target_found(node: Node2D):
	_target_player = false


func _on_TargetBehavior_target_player(node: Node2D):
	_target_player = true
