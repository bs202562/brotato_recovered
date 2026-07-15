extends Carousel


func _ready():
	super._ready() # 4.x 移植: Godot 3 自动调用父类虚函数，4.x 需显式调用
	for child in _headings.get_children():
		if child.player_index >= RunData.get_player_count():
			_headings.remove_child(child)
			child.queue_free()
