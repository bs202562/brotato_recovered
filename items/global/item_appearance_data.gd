class_name ItemAppearanceData
extends Resource

enum Position{OTHER, ABOVE_HEAD, TOP_LEFT, TOP_RIGHT, HAT, FOREHEAD, EYES, NOSE, MOUTH, BACK, NECK, TORSO, POCKET_LEFT, POCKET_RIGHT, SKIN, TAIL, ACCESSORY_LEFT, ACCESSORY_RIGHT}
enum Priority{VERY_LOW, LOW, MEDIUM, HIGH, VERY_HIGH}

export (Resource) var sprite = null
export (Position) var position = Position.OTHER
export (Priority) var display_priority = Priority.VERY_LOW
export (float) var depth = 1.0
export (bool) var is_character_appearance = false


func get_sprite() -> Resource:
	return SkinManager.get_skin(sprite)


func serialize() -> Dictionary:
	var serialized = {
		"position": position, 
		"display_priority": display_priority, 
		"depth": depth, 
		"is_character_appearance": is_character_appearance
	}

	if sprite != null:
		serialized.sprite = sprite.resource_path

	return serialized


func deserialize_and_merge(serialized: Dictionary):
	position = serialized.position as int
	display_priority = serialized.display_priority as int
	depth = serialized.depth
	if serialized.has("is_character_appearance"):
		is_character_appearance = serialized.is_character_appearance

	if serialized.has("sprite"):
		sprite = load(serialized.sprite)
