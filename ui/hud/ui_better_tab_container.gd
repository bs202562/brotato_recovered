class_name UIBetterTabContainer
extends Container


export var use_shoulder_to_swap_tab: bool = true
export (Array, NodePath) var buttons_tab_np
export (NodePath) var tab_container_np

onready var tab_container: TabContainer = get_node(tab_container_np)
var buttons_tab: Array
var _focus_emulator: FocusEmulator

var previous_pressed: Button

func _ready():
	if RunData.is_coop_run:
		_focus_emulator = Utils.get_focus_emulator(0)
	
	var buttonGroup: ButtonGroup = ButtonGroup.new()
	for i in buttons_tab_np.size():
		var button: Button = get_node(buttons_tab_np[i])
		buttons_tab.append(button)
		button.toggle_mode = true
		button.group = buttonGroup
		button.connect("pressed", self, "_change_tab", [i])

	buttons_tab[0].pressed = true
	_change_tab(0)


func _is_visible():
	pass


func _input(event):
	if not is_visible_in_tree():
		return
	if use_shoulder_to_swap_tab:
		if event.is_action_pressed("ltrigger"):
			var button: Button = get_node(buttons_tab_np[max(tab_container.current_tab - 1, 0)])
			if button.disabled: return
			tab_container.current_tab -= 1
			buttons_tab[tab_container.current_tab].pressed = true
		if event.is_action_pressed("rtrigger"):
			var button: Button = get_node(buttons_tab_np[min(tab_container.current_tab + 1, buttons_tab_np.size() - 1)])
			if button.disabled: return
			tab_container.current_tab += 1
			buttons_tab[tab_container.current_tab].pressed = true

		if event.is_action_pressed("ltrigger") or event.is_action_pressed("rtrigger"):
			buttons_tab[tab_container.current_tab].grab_focus()


func _change_tab(actual_tab: int):
	var button: Button = get_node(buttons_tab_np[actual_tab])
	if button.disabled and not button.pressed: return
	tab_container.current_tab = actual_tab
	if not button.pressed: button.pressed = true
