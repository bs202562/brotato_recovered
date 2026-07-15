extends Node

var list_of_limitated_sounds_playing: Dictionary


func play_sound_with_limit(sound_id: String, audio: AudioStream, max_play: int, player: AudioStreamPlayer = null, volume_mod: float = 0.0, pitch_rand: float = 0.0, always_play: bool = false):
	if how_many_times_sound_currently_playing(sound_id) > max_play:
		return
	list_of_limitated_sounds_playing[sound_id] += 1

	if player == null:
		SoundManager.play(audio, volume_mod, pitch_rand, always_play)
	else:
		player.stream = audio
		player.play()

	await get_tree().create_timer(audio.get_length()).timeout

	list_of_limitated_sounds_playing[sound_id] -= 1


func play_sound2d_with_limit(sound_id: String, audio: AudioStream, max_play: int, position: Vector2, volume_mod: float = 0.0, pitch_rand: float = 0.0, always_play: bool = false):
	if how_many_times_sound_currently_playing(sound_id) > max_play:
		return
	list_of_limitated_sounds_playing[sound_id] += 1

	SoundManager2D.play(audio, position, volume_mod, pitch_rand, always_play)

	await get_tree().create_timer(audio.get_length()).timeout

	list_of_limitated_sounds_playing[sound_id] -= 1


func how_many_times_sound_currently_playing(sound_id: String):
	if not list_of_limitated_sounds_playing.has(sound_id):
		list_of_limitated_sounds_playing[sound_id] = 0

	return list_of_limitated_sounds_playing[sound_id]
