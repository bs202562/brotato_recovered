extends Node






var _popinPrefab: PackedScene
var _popinInstance: Popin
var _callback: FuncRef
var _lastFocusNode: Control
var _canvasLayer: CanvasLayer


func _ready() -> void :
	_popinPrefab = load("res://ui/menus/global/popin.tscn")
	_popinInstance = _popinPrefab.instance();
	_popinInstance.connect("confirm", self, "_on_confirm")
	_canvasLayer = CanvasLayer.new()
	_canvasLayer.layer = 9999
	_canvasLayer.add_child(_popinInstance)
	_canvasLayer.pause_mode = Node.PAUSE_MODE_PROCESS
	get_viewport().connect("gui_focus_changed", self, "_on_focus_changed")
	pass

func show(description: String, confirmLabel: String, target: Object = null, callbackName: String = "") -> void :
	if _canvasLayer.get_parent() == null:
		get_tree().root.add_child(_canvasLayer)
	_popinInstance.setContent(description, confirmLabel)
	if target != null and callbackName != null and callbackName != "":
		_callback = funcref(target, callbackName)
	else:
		_callback = null
	
func hide() -> void :
	_popinInstance.clean()
	_callback = null
	if _lastFocusNode != null and is_instance_valid(_lastFocusNode):
		_lastFocusNode.grab_focus()
	_lastFocusNode = null
	call_deferred("_delay_remove_popin")

func _delay_remove_popin():
	get_tree().root.remove_child(_canvasLayer)
	
func _on_confirm() -> void :
	var cb = _callback
	hide();
	if cb != null and cb.is_valid():
		cb.call_func()
	
	
func _on_focus_changed(node: Control) -> void :
	if not _canvasLayer.is_a_parent_of(node):
		_lastFocusNode = node;

