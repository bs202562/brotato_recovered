class_name PooledParticles
extends CPUParticles2D

@onready var _finished_timer: Timer = $"%FinishedTimer"


signal is_finished(object) # 4.x 移植: 原名 finished 与 CPUParticles2D 内置信号冲突，重命名


func _ready():
	var _error: = _finished_timer.connect("timeout", Callable(self, "_on_FinishedTimer_timeout"))


func restart(keep_seed: bool = false) -> void :
	show()
	_finished_timer.start()
	super.restart(keep_seed)


func _on_FinishedTimer_timeout() -> void :
	emit_signal("is_finished", self)
