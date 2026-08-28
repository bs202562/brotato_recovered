class_name Bat
extends Boss

var is_on_long_cooldown: bool = false


func init(zone_min_pos: Vector2, zone_max_pos: Vector2, players_ref: Array = [], entity_spawner_ref = null) -> void :
	.init(zone_min_pos, zone_max_pos, players_ref, entity_spawner_ref)

	var _e = _attack_behavior.connect("entered_long_cooldown", self, "on_entered_long_cooldown")
	_e = _attack_behavior.connect("shot", self, "on_shot")

	for state in _states_container.get_children():
		_e = state.attack_behavior.connect("entered_long_cooldown", self, "on_entered_long_cooldown")
		_e = state.attack_behavior.connect("shot", self, "on_shot")


func on_state_changed(new_state: int) -> void :
	.on_state_changed(new_state)

	if new_state == 0:
		reset_speed_stat(30)


func on_entered_long_cooldown() -> void :
	reset_speed_stat( - 35)
	is_on_long_cooldown = true


func on_shot() -> void :
	if is_on_long_cooldown:
		if _current_state == - 1:
			reset_speed_stat(0)
		else:
			reset_speed_stat(30)

		is_on_long_cooldown = false
