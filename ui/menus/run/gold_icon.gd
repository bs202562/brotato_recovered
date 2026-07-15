extends TextureRect

func _ready() -> void :
	modulate = Utils.GOLD_COLOR


func set_icon(icon: Texture2D, color: Color = Color.WHITE) -> void :
	texture = icon
	modulate = color
