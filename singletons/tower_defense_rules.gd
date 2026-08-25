extends Node

# Central configuration for the portrait tower-defense conversion.
const ENABLED: bool = true
const DESIGN_WIDTH: int = 1080
const DESIGN_HEIGHT: int = 1920
const MAP_WIDTH_TILES: int = 17
const MAP_HEIGHT_TILES: int = 30
const HERO_POSITION: Vector2 = Vector2(544, 1700)
const TOP_SPAWN_MIN_Y: float = 64.0
const TOP_SPAWN_MAX_Y: float = 192.0
const SIDE_SPAWN_MARGIN: float = 64.0

const DISABLED_EFFECT_KEYS: Array = [
	"stat_speed",
	"pickup_range",
	"map_size",
	"temp_stats_while_moving",
	"gold_while_moving",
	"structure_attack_speed_while_moving",
	"can_attack_while_moving"
]


func get_top_spawn_position() -> Vector2:
	var zone_rect: Rect2 = ZoneService.get_current_zone_rect()
	var min_x: float = zone_rect.position.x + SIDE_SPAWN_MARGIN
	var max_x: float = zone_rect.end.x - SIDE_SPAWN_MARGIN
	var min_y: float = zone_rect.position.y + TOP_SPAWN_MIN_Y
	var max_y: float = min(zone_rect.end.y - SIDE_SPAWN_MARGIN, zone_rect.position.y + TOP_SPAWN_MAX_Y)
	return Vector2(rand_range(min_x, max_x), rand_range(min_y, max_y))


func get_camera_position() -> Vector2:
	return Vector2(
		MAP_WIDTH_TILES * Utils.TILE_SIZE / 2.0,
		MAP_HEIGHT_TILES * Utils.TILE_SIZE / 2.0
	)


func is_content_compatible(content: Resource) -> bool:
	if not ENABLED or content == null or not "effects" in content:
		return true
	for effect in content.effects:
		if effect == null:
			continue
		if "key" in effect and DISABLED_EFFECT_KEYS.has(effect.key):
			return false
		if "custom_key" in effect and DISABLED_EFFECT_KEYS.has(effect.custom_key):
			return false
	return true
