class_name MainScreenArtButton
extends OptionButton


func _ready() -> void :
	clear()
	add_item("DEFAULT", 0)
	add_item("KEY_ART_RANDOM", 1)
	add_separator()
	var indx: int = 2
	for screen in ItemService.title_screen_backgrounds:
		add_item(screen.my_id, indx)
		indx += 1
