class_name TargetRandGoldPosBehavior
extends MovementBehavior

var _current_target: Vector2 = Vector2.ZERO

var _init_done: = false # 4.x 移植: 原名 init 与父类 Behavior.init 冲突，重命名
var main: Main
var golds

func get_movement() -> Vector2:
	if _current_target == Vector2.ZERO or Utils.vectors_approx_equal(_current_target, _parent.global_position, EQUALITY_PRECISION):
		_current_target = get_new_target()

	return _current_target - _parent.global_position


func get_target_position():
	return _current_target

func init_main():
	if not _init_done:
		var entity_spawner = get_parent()._entity_spawner_ref
		main = entity_spawner._main

func get_new_target() -> Vector2:
	init_main()
	if (main._active_golds.size() <= 0):
		return Vector2(
					randf_range(_parent._min_pos.x, _parent._max_pos.x), 
					randf_range(_parent._min_pos.y, _parent._max_pos.y)
				)

	return Utils.get_rand_element(main._active_golds).position
