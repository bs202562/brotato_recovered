extends Node

signal stopped
signal started

var _lastState: = false
var _guestCount: = 0;


func _ready():
	pass

func start(internet: bool, config: Dictionary) -> int:
	if Utils.on_nintendo_ounce:
		set_process(true)
		_guestCount = OS_Seaven.start_streamplay(internet, config)
		emit_signal("started")
		return _guestCount
	return - 1
	
func stop():
	if Utils.on_nintendo_ounce:
		OS_Seaven.stop_streamplay();
		set_process(false)
		_guestCount = 0
		_lastState = false;
		OS_Seaven.set_max_controller_count(1)
		emit_signal("stopped")

func guests():
	return _guestCount

func playing():
	if Utils.on_nintendo_ounce:
		return OS_Seaven.check_streamplay_state(true)
	return false

func is_online():
	return false;
	
func _on_popin_confirmed():
	get_tree().paused = false
	var _error = get_tree().change_scene_to_file(MenuData.title_screen_scene)
	ProgressData.end_activity(false)


func _process(_delta):
	if Utils.on_nintendo_ounce:
		match RunData.play_mode:
			RunData.PlayMode.STREAMPLAY_LOCAL, RunData.PlayMode.STREAMPLAY_INTERNET:
					var state = OS_Seaven.check_streamplay_state(true);
					if not state and state != _lastState:
						set_process(false)
						stop()
						get_tree().paused = true
						PopinManager.show("NETWORK_INTERRUPTED", "MENU_RETURN_MAIN", self, "_on_popin_confirmed")
					_lastState = state
					
