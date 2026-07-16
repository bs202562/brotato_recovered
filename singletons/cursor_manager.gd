extends Node

const normal_image = preload("res://ui/custom_cursor.png")
const manual_image = preload("res://ui/manual_cursor.png")
var current_image = null


func _ready() -> void :
	process_mode = PROCESS_MODE_ALWAYS


func _process(_delta):
	if Input.get_mouse_mode() == Input.MOUSE_MODE_HIDDEN:
		
		return
	var new_image = get_cursor_image()
	if new_image == current_image:
		return
	var hotspot = get_cursor_hotspot(new_image)
	Input.set_custom_mouse_cursor(new_image, Input.CURSOR_ARROW, hotspot)
	current_image = new_image


func get_cursor_image() -> Resource:
	var tree = get_tree()
	var current_scene = tree.current_scene

	# 4.x 移植: change_scene_to_file() 会立刻把 current_scene 置空，新场景要到本帧末
	# 才挂上，中间存在空窗期(3.x 换场景是原子的，不会出现)。本单例是
	# PROCESS_MODE_ALWAYS、每帧都跑，切场景时会撞进空窗期，故需判空。
	# 空窗期没有场景可询问，按默认光标处理。
	if current_scene == null:
		return normal_image

	var show_manual_cursor = (
		current_scene.has_method("show_manual_cursor")
		and current_scene.show_manual_cursor()
		and not tree.paused
	)
	return manual_image if show_manual_cursor else normal_image


func get_cursor_hotspot(cursor_image: Resource) -> Vector2:
	match cursor_image:
		normal_image: return Vector2(3, 3)
		manual_image: return Vector2(35, 35)
		_: return Vector2(0, 0)


func get_tooltip_offset() -> Vector2:
	return Vector2(40, 40)
