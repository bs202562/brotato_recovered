class_name DocMoth
extends Pet

export (Array, Resource) var effects
export (Color) var color_player_modulation = Color(0.6, 1.6, 1.1)
export (String) var hp_gained_tracking_id
export (AudioStreamSample) var sound_enter_zone
export (AudioStreamSample) var sound_exit_zone

onready var _boost_zone: Area2D = $"BoostZone"

var _hp_gained_tracking_id_hash: int = Keys.empty_hash

var players_inside: int = 0

func init(zone_min_pos: Vector2, zone_max_pos: Vector2, p_players_ref: Array = [], entity_spawner_ref = null) -> void :
	.init(zone_min_pos, zone_max_pos, p_players_ref, entity_spawner_ref)

	_hp_gained_tracking_id_hash = Keys.generate_hash(hp_gained_tracking_id)

func update_data(effect: PetEffect) -> void :
	.update_data(effect)
	_boost_zone.scale = Vector2(effect.boost_zone_scale, effect.boost_zone_scale)

func _on_BoostZone_body_entered(body):
	if not RunData.wave_in_progress:
		return

	if body is Player:
		var player = body as Player
		var player_index = player.player_index
		RunData.apply_effects_array(effects, player_index)
		player._set_color_modulation(color_player_modulation)
		SoundService.play_sound2d_with_limit("doc_moth", sound_enter_zone, 2, global_position, 0, 0.1)
		players_inside += 1
		body.inside_doc_moth_area.push_back(self)
		body.connect("healed", self, "_on_player_heal")


func _on_player_heal(value, player_index):
	var _main: Main = get_tree().current_scene
	var player: Player = _main._players[player_index]
	if player.inside_doc_moth_area[0] == self:
		RunData.add_tracked_value(player_index, _hp_gained_tracking_id_hash, value - (value / (player.inside_doc_moth_area.size() * 2)))


func _on_BoostZone_body_exited(body):
	if body is Player:
		var player = body as Player
		var player_index = player.player_index
		RunData.unapply_effects_array(effects, player_index)
		player.remove_color_modulation(color_player_modulation)
		SoundService.play_sound2d_with_limit("doc_moth", sound_exit_zone, 2, global_position, 0, 0.1)
		players_inside -= 1
		body.inside_doc_moth_area.erase(self)
		body.disconnect("healed", self, "_on_player_heal")


func update_animation(movement: Vector2) -> void :
	.update_animation(movement)
	if not (_animation_player.current_animation == "idle_healbooster"):
		_animation_player.play("idle_healbooster")


func _update_transparency(value):
	._update_transparency(value)
	yield(get_tree(), "idle_frame")
	_boost_zone.modulate.a = value
