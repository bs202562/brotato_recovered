class_name WaveTimer
extends Timer

signal tick_started

export (Array, Resource) var tick_sounds

onready var half_wave_timer = $HalfWaveTimer
onready var tick_timer = $TickTimer

var signalled = false


func _physics_process(_delta: float) -> void :
	if time_left < 6.0 and time_left > 0.1 and tick_timer.is_stopped():
		tick_timer.start()


func start(time_sec: float = - 1) -> void :
	.start(time_sec)
	half_wave_timer.start(wait_time / 2.0)


func stop() -> void :
	tick_timer.stop()
	paused = true


func _on_TickTimer_timeout() -> void :
	SoundManager.play(Utils.get_rand_element(tick_sounds), 0, 0.1, true)
	if not signalled:
		emit_signal("tick_started")
		signalled = true


func _on_WaveTimer_timeout() -> void :
	tick_timer.stop()
