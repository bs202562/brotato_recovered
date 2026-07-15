extends Viewport

export (String) var file_name
var frame_index: int = 0

func _process(delta):
	if Input.is_action_pressed("ui_ban"):
		var capture: = get_texture().get_data()
		var file_path = "user://" + file_name + "_" + str(frame_index).pad_zeros(6) + ".png"
		capture.save_png(file_path)

		frame_index += 1
