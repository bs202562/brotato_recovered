class_name ForEveryStepEffectBehavior
extends PlayerEffectBehavior

const STEPS_PER_MOVE_ANIMATION: int = 2
const CHALLENGE_ID: String = "chal_smelly_feet"
var CHALLENGE_ID_HASH: int = Keys.generate_hash(CHALLENGE_ID)

var _move_animation_duration_secs: = 0.0
var _steps_taken: = 0.0


func _ready() -> void :
	_move_animation_duration_secs = _parent._animation_player.get_animation(_parent.animation_move).length


func _exit_tree():
	var steps_taken_total: int = ProgressData.data["steps_taken"] + RunData.steps_taken_this_wave[_player_index]
	ChallengeService.try_complete_challenge(CHALLENGE_ID_HASH, steps_taken_total)


func should_add_on_spawn() -> bool:
	return true


func on_moved(delta_position: Vector2) -> void :
	var px_per_second: = _parent.get_move_speed()
	if px_per_second == 0.0:
		return

	
	var seconds_per_animation: = _move_animation_duration_secs / _parent._animation_player.playback_speed
	var steps_taken_before: = _steps_taken
	_steps_taken += (float(STEPS_PER_MOVE_ANIMATION) / seconds_per_animation) * (delta_position.length() / px_per_second)

	var gain_stat_for_every_step_after_equip_effects = RunData.get_player_effect(Keys.gain_stat_for_every_step_after_equip_hash, _player_index)
	for effect in gain_stat_for_every_step_after_equip_effects:
		assert (effect[0] is int)
		var stuff_added = handle_stat_for_steps(effect[0], effect[1], int(effect[2]), steps_taken_before)
		assert (stuff_added.size() > 1)
		if stuff_added[0] > 0:
			RunData.add_tracked_value(_player_index, Keys.character_hiker_hash, stuff_added[0], 0)
			
		if stuff_added[1] > 0:
			RunData.add_tracked_value(_player_index, Keys.character_hiker_hash, stuff_added[1], 1)
			

	for weapon in _parent.current_weapons:
		for effect in weapon.effects:
			if effect.custom_key_hash == Keys.gain_stat_for_every_step_after_equip_hash:
				var stuff_added = handle_stat_for_steps(effect.key_hash, effect.value, int(effect.value2), steps_taken_before)
				if stuff_added[1] > 0:
					weapon.emit_signal("tracked_value_updated", effect.value)

	
	
	RunData.steps_taken_this_wave[_player_index] += int(_steps_taken) - int(steps_taken_before)


func handle_stat_for_steps(stat: int, value: int, for_every_step_count: int, steps_taken_before: float) -> Array:
	var stuff_added = [0, 0]
	for new_step in range(int(steps_taken_before), int(_steps_taken)):
		if (new_step + 1) % for_every_step_count != 0:
			continue
		if stat == Keys.gold_hash:
			RunData.add_gold(value, _player_index)
			stuff_added[0] += value
		else:
			RunData.add_stat(stat, value, _player_index)
			stuff_added[1] += value
	return stuff_added


func calculate_move_distance_for_steps(steps: int) -> float:
	return _parent.current_stats.speed * steps * _move_animation_duration_secs / STEPS_PER_MOVE_ANIMATION
