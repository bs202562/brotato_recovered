class_name Announcement
extends Control

@onready var _image: TextureRect = $"%Image"
var _tween: Tween = null
@onready var _announcement_container: VBoxContainer = $"%AnnouncementContainer"
@onready var _speech_bubble: PanelContainer = $"%SpeechBubblePanel"

var _closing: = false


func _ready() -> void :
	if AnnouncementManager.display_announcement:
		display_announcement()
	var _err: int = AnnouncementManager.connect("announcement_ready", Callable(self, "_on_announcement_ready"))


func _on_announcement_ready() -> void :
	display_announcement()


func display_announcement() -> void :
	_image.texture = AnnouncementManager.get_image()

	if AnnouncementManager.initial_display:
		var start: = Vector2(position.x - _announcement_container.size.x, position.y)
		if _tween:
			_tween.kill()
		_tween = create_tween()
		var _res = _tween.tween_property(self, "position", position, 0.5).from(start).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		visible = true
		AnnouncementManager.initial_display = false

	else:
		visible = true


func _on_CloseButton_pressed() -> void :
	_closing = true
	AnnouncementManager.announcement_read()

	var end: = Vector2(position.x - _announcement_container.size.x, position.y)
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	var _res = _tween.tween_property(self, "position", end, 0.4).from(position).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_res = _tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1).from(scale).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _on_Tween_tween_started(_object: Object, _key: NodePath) -> void :
	await get_tree().process_frame
	visible = true


func _on_AnnouncementButton_pressed() -> void :
	var link: = tr("ANNOUNCEMENT_LINK")
	if link:
		Platform.open_store_page(link)
		_speech_bubble.remove_theme_stylebox_override("panel")


func _on_PanelContainer_mouse_entered() -> void :
	var hover_stylebox = _speech_bubble.get_theme_stylebox("hover")
	_speech_bubble.add_theme_stylebox_override("panel", hover_stylebox)


func _on_PanelContainer_mouse_exited() -> void :
	if _closing:
		return
	_speech_bubble.remove_theme_stylebox_override("panel")


func _on_AnnouncementButton_button_down() -> void :
	_speech_bubble.remove_theme_stylebox_override("panel")


func _on_AnnouncementButton_button_up() -> void :
	var hover_stylebox = _speech_bubble.get_theme_stylebox("hover")
	_speech_bubble.add_theme_stylebox_override("panel", hover_stylebox)


func _on_Announcement_mouse_entered() -> void :
	if _closing:
		return

	if _tween:
		_tween.kill()
	_tween = create_tween()
	var _res = _tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1).from(scale).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _on_Announcement_mouse_exited() -> void :
	if _tween:
		_tween.kill()
	_tween = create_tween()
	var _res = _tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1).from(scale).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
