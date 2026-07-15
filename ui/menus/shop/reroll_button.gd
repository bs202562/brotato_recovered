class_name RerollButton
extends ButtonWithIcon

const TIME_LOADING: float = 0.5

var _is_loading: bool = false

func init(value: int, player_index: int) -> void :
	set_value(value, RunData.get_player_gold(player_index))
	var txt: = (tr("REROLL") + " - " + str(value)).to_upper()
	if RunData.is_coop_run:
		set_text(txt)
	else:
		set_text("      " + txt)


func _ready():
	super._ready() # 4.x 移植: Godot 3 自动调用父类虚函数，4.x 需显式调用
	if RunData.is_coop_run:
		var icon: = get_node_or_null("AdditionalIcon")
		if icon != null:
			icon.hide()
	connect("pressed", Callable(self, "_on_button_pressed"))


func _on_button_pressed():
	_is_loading = false


func _input(event):
	if not RunData.is_coop_run and is_visible_in_tree():
		if event.is_action_pressed("ui_info"):
			if ProgressData.settings.holding_button:
				_is_loading = true
				_load_button()
			else:
				emit_signal("pressed")
				emit_signal("focus_exited")
		elif event.is_action_released("ui_info"):
			_is_loading = false


func _load_button():
	var progressbar = get_node_or_null("progress_reroll")
	if progressbar == null: return
	while true:
		progressbar.value += (1 / TIME_LOADING) * get_process_delta_time()
		if progressbar.value >= 1:
			break
		if not _is_loading:
			progressbar.value = 0
			return
		await get_tree().process_frame

	progressbar.value = 0
	emit_signal("pressed")
	emit_signal("focus_exited")
