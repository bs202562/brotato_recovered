class_name BackgroundData
extends Resource

@export var name: String = ""
@export var icon: Resource = null
@export var outline_color: Color = Color.WHITE
@export var tiles_sprite: Resource = null


func get_tiles_sprite() -> Resource:
				return SkinManager.get_skin(tiles_sprite)
