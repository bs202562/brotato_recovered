class_name FollowRandPosAroundPlayerMovementBehavior
extends MovementBehavior

@export var range_around_player: int = 200
@export var range_randomization: int = 0
@export var allow_within: bool = true

var _actual: int
var _distance_from_player: Vector2


func init(parent: Node) -> Node:
	var _init = super.init(parent)
	_actual = range_around_player + randf_range( - range_randomization, range_randomization)
	_distance_from_player = Vector2(randf_range( - _actual, _actual), randf_range( - _actual, _actual))

	if not allow_within:
		_distance_from_player = _distance_from_player.normalized() * _actual

	return self


func get_movement() -> Vector2:
	var target = get_target_position()

	if Utils.vectors_approx_equal(target, _parent.global_position, EQUALITY_PRECISION):
		return Vector2.ZERO

	return target - _parent.global_position


func get_target_position():
	return _parent.current_target.global_position + _distance_from_player
