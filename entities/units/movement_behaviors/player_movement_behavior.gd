class_name PlayerMovementBehavior
extends MovementBehavior

const MIN_MOVE_DIST = 20

var device: = 0


func get_movement() -> Vector2:
	var movement: Vector2 = Vector2.ZERO

	if ProgressData.settings.mouse_only and not RunData.is_coop_run:
		var mouse_pos = get_global_mouse_position()
		movement = Vector2(mouse_pos.x - _parent.global_position.x, mouse_pos.y - _parent.global_position.y)

		if (abs(movement.x) < MIN_MOVE_DIST and abs(movement.y) < MIN_MOVE_DIST) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			movement = Vector2.ZERO
	else:
		var analog_input: Vector2 = get_vector_for_input_prefix("analog_")
		var button_input: Vector2 = get_vector_for_input_prefix("button_")
		if analog_input.length() > button_input.length():
			movement = analog_input
		else:
			movement = button_input
	return movement



func get_vector_for_input_prefix(prefix: String) -> Vector2:
	if RunData.is_coop_run:
		return Input.get_vector(prefix + "move_left_%s" % device, prefix + "move_right_%s" % device, prefix + "move_up_%s" % device, prefix + "move_down_%s" % device)
	else:
		return Input.get_vector(prefix + "move_left", prefix + "move_right", prefix + "move_up", prefix + "move_down")
