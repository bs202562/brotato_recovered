# ============================================================
# 地面 TileMap —— 按区域尺寸铺随机地砖变体
#
# 4.x 移植说明：Godot 3 的 TileSet(autotile+priority) 资源格式与 4.x
# 完全不兼容（场景里引用的 ground_tiles.tres 在 4.x 下加载为空），
# 因此改为运行时用 TileSetAtlasSource 从贴图动态重建图集。
# 原 3.x 资源数据：图集 192×256 = 3×4 个 64×64 子块，
# priority_map 里子块 (2,3) 权重 50（素色地面），其余权重 1。
# 每个区域开波时 main.gd 会调 set_tiles_texture() 换用对应贴图。
# ============================================================
class_name MyTileMap
extends TileMap

const TILE_PX := 64
# 原 ground_tiles.tres 的 priority_map: [Vector3(2,3,50)]
const PRIORITY_TILE := Vector2i(2, 3)
const PRIORITY_WEIGHT := 50

@onready var outline = $Outline

var _source_id: int = -1
var _grid_w: int = 3
var _grid_h: int = 4


func init(zone: ZoneData) -> void :
	outline.size = Vector2(Utils.TILE_SIZE * (zone.width + 2), Utils.TILE_SIZE * (zone.height + 2))
	if _source_id == -1 and tile_set != null and tile_set.get_source_count() > 0:
		# set_tiles_texture 未被调用时的兜底(理论上 main.gd 总会先调它)
		_source_id = tile_set.get_source_id(0)
	for i in zone.width:
		for j in zone.height:
			my_set_cell(i, j)


# 4.x 移植: 用给定贴图构建一个按 64×64 切块的 TileSet。
# 3.x 的 TileSet 资源(ground_tiles.tres)格式与 4.x 完全不兼容、加载出来是空的，
# 故一律运行时重建。source id 固定为 0，与场景中已摆放格子的引用保持一致。
# 静态方法：本类与 character_panel_ui.gd(普通 TileMap 节点)共用。
static func build_tileset(tex: Texture2D) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_PX, TILE_PX)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE_PX, TILE_PX)
	var gw: int = max(1, int(tex.get_width() / TILE_PX))
	var gh: int = max(1, int(tex.get_height() / TILE_PX))
	for x in gw:
		for y in gh:
			src.create_tile(Vector2i(x, y))
	ts.add_source(src, 0)
	return ts


# 4.x 移植: 替代原 main.gd 中的 tile_set.tile_set_texture(0, tex)。
func set_tiles_texture(tex: Texture2D) -> void :
	if tex == null:
		return
	_grid_w = max(1, int(tex.get_width() / TILE_PX))
	_grid_h = max(1, int(tex.get_height() / TILE_PX))
	tile_set = build_tileset(tex)
	_source_id = 0


func my_set_cell(x: int, y: int) -> void :
	set_cell(0, Vector2i(x, y), _source_id, get_subtile_with_priority())


# 按权重随机取一个图集子块：(2,3) 权重 50，其余 1(还原 3.x priority_map)
func get_subtile_with_priority() -> Vector2i:
	var has_priority_tile: bool = PRIORITY_TILE.x < _grid_w and PRIORITY_TILE.y < _grid_h
	var plain_count: int = _grid_w * _grid_h - (1 if has_priority_tile else 0)
	var total: int = plain_count + (PRIORITY_WEIGHT if has_priority_tile else 0)

	var r: int = Utils.randi() % max(1, total)
	if has_priority_tile:
		if r < PRIORITY_WEIGHT:
			return PRIORITY_TILE
		r -= PRIORITY_WEIGHT

	var idx := 0
	for x in _grid_w:
		for y in _grid_h:
			if has_priority_tile and Vector2i(x, y) == PRIORITY_TILE:
				continue
			if idx == r:
				return Vector2i(x, y)
			idx += 1
	return PRIORITY_TILE
