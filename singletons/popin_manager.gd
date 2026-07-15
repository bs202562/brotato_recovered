extends Node






var _popinPrefab: PackedScene
var _popinInstance: Popin
var _callback: Callable
var _lastFocusNode: Control
var _canvasLayer: CanvasLayer


func _ready() -> void :
	_popinPrefab = load("res://ui/menus/global/popin.tscn")
	_popinInstance = _popinPrefab.instantiate();
	_popinInstance.connect("confirm", Callable(self, "_on_confirm"))
	_canvasLayer = CanvasLayer.new()
	_canvasLayer.layer = 9999
	_canvasLayer.add_child(_popinInstance)
	_canvasLayer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().connect("gui_focus_changed", Callable(self, "_on_focus_changed"))
	pass

func show(description: String, confirmLabel: String, target: Object = null, callbackName: String = "") -> void :
	if _canvasLayer.get_parent() == null:
		get_tree().root.add_child(_canvasLayer)
	_popinInstance.setContent(description, confirmLabel)
	if target != null and callbackName != null and callbackName != "":
		_callback = Callable(target, callbackName)
	else:
		_callback = Callable()
	
func hide() -> void :
	_popinInstance.clean()
	_callback = Callable()
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
		cb.call()
	
	
func _on_focus_changed(node: Control) -> void :
	if not _canvasLayer.is_ancestor_of(node):
		_lastFocusNode = node;

