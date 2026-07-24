extends Node

var bus = "Music"
var player: AudioStreamPlayer
var _tween: Tween

export (Array, Resource) var old_tracks
export (Array, Resource) var new_tracks

var shuffled_tracks: = []

# 微信外置：曲目 mp3 已从 pck 抽出，运行时经 WxAssets 按需下载再注入。
# 未就绪时先静默，就绪后经 audio_ready 信号补播这首。
var _waiting_track = null
var _waiting_volume := 0.0


func _ready() -> void :
	pause_mode = PAUSE_MODE_PROCESS
	player = AudioStreamPlayer.new()
	_tween = Tween.new()
	add_child(_tween)
	add_child(player)
	player.bus = bus

	var _error = player.connect("finished", self, "on_track_finished")
	if Engine.has_singleton("WxAssets") or has_node("/root/WxAssets"):
		WxAssets.connect("audio_ready", self, "_on_audio_ready")


func on_track_finished() -> void :
	play()


func set_shuffled_tracks() -> void :
	shuffled_tracks = []

	if ProgressData.settings.streamer_mode_tracks:
		shuffled_tracks.append_array(new_tracks.duplicate())

	if ProgressData.settings.legacy_tracks:
		shuffled_tracks.append_array(old_tracks.duplicate())

	for dlc_id in ProgressData.get_active_dlc_tracks():
		var dlc_data = ProgressData.get_dlc_data(dlc_id)
		if dlc_data:
			shuffled_tracks.append_array(dlc_data.music_tracks.duplicate())

	shuffled_tracks.shuffle()


func play(volume: float = player.volume_db) -> void :

	if shuffled_tracks.size() <= 0:

		if has_tracks_to_add():
			set_shuffled_tracks()
		else:
			player.stop()
			return

	var new_track = shuffled_tracks.pop_back()

	# 避免连播同一首（原逻辑）
	if new_track == player.stream and shuffled_tracks.size() > 0:
		new_track = shuffled_tracks.pop_back()

	_play_resolved(new_track, volume)


# 微信外置：解析真实音频流。就绪则播，未就绪则登记等待（先静默）。
func _play_resolved(track, volume: float) -> void :
	var real = WxAssets.get_audio_stream(track)
	if real != null:
		_waiting_track = null
		player.stream = real
		player.volume_db = - 20
		player.play()
		tween(volume)
	else:
		_waiting_track = track
		_waiting_volume = volume


func _on_audio_ready(res_path: String) -> void :
	if _waiting_track != null and _waiting_track.resource_path == res_path:
		var t = _waiting_track
		_waiting_track = null
		_play_resolved(t, _waiting_volume)


func has_tracks_to_add() -> bool:
	return ProgressData.settings.legacy_tracks or ProgressData.settings.streamer_mode_tracks or ProgressData.get_active_dlc_tracks().size() > 0


func tween(to: float, from: float = player.volume_db, duration: float = 1) -> void :
	if _tween.is_active():
		yield(_tween, "tween_all_completed")

	var _error_interpolate = _tween.interpolate_property(
		player, 
		"volume_db", 
		from, 
		to, 
		duration, 
		Tween.TRANS_LINEAR
	)

	var _error = _tween.start()
