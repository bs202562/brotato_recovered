class_name WaveClearedLabel
extends Label

@export var font_end_run: Resource
@export var character_appearing_sounds: Array = [] # (Array, Resource)


func _ready() -> void :
	visible_characters = 0


func start(is_wave_failed: = false, is_run_lost: = false, is_run_won: = false) -> void :

	if is_run_won:
		if is_wave_failed:
			text = "WAVE_FAILED"
		else:
			text = "RUN_WON"

	if is_run_lost:
		text = "RUN_LOST"

	add_theme_font_override("font", font_end_run)

	DebugService.log_data("start timer...")

	$Timer.start()


func _on_Timer_timeout() -> void :
	visible_characters += 1
	SoundManager.play(Utils.get_rand_element(character_appearing_sounds), - 10, 0.2)
	if visible_ratio < 1.0:
		$Timer.start()
