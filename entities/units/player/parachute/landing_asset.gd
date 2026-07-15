extends Node2D

@onready var _anim_player: AnimationPlayer = $AnimationPlayer
@onready var _swiming_buble: CPUParticles2D = $SwimingBubble
@onready var _parachute = $Parachute_sprite
@onready var _audio_stream_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

@export var _sound_underwater: AudioStreamWAV

signal animation_finished

func _play(underwater: bool = false):
	_anim_player.play("land")

	if underwater:
		_swiming_buble.emitting = true
		_parachute.visible = false
		_audio_stream_player.stream = _sound_underwater
		_audio_stream_player.play()

	await _anim_player.animation_finished
	emit_signal("animation_finished")

	if underwater:
		_swiming_buble.emitting = false
		await get_tree().create_timer(_swiming_buble.lifetime).timeout
	queue_free()
