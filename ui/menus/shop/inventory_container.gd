class_name InventoryContainer
extends VBoxContainer

signal elements_changed

@export var focus_neighbour_strategy: = Inventory.FocusNeighbourStrategy.SCROLL_THROUGH # (Inventory.FocusNeighbourStrategy)
@export var set_neighbour_top := false
@export var set_neighbour_bottom := false
@export var set_neighbour_right := false
@export var set_neighbour_left := false
@export var authorize_sorting := false

@export var display_locked_icon := true
@export var display_banned: = 0.0 # (float, 0, 1)
@export var item_background_transparency: = 0.25 # (float, 0, 1)
@export var item_background_modulate := Color(1, 1, 1, 0)

@export var reserve_column_count := 1: set = _set_reserve_column_count
func _set_reserve_column_count(v: int) -> void :
	reserve_column_count = v
	if _elements:
		_elements.columns = reserve_column_count
	if _scroll_size_container:
		_scroll_size_container.custom_minimum_size.x = _get_scroll_size_for_column_count(reserve_column_count)

@export var reserve_row_count := 2: set = _set_reserve_row_count
func _set_reserve_row_count(v: int) -> void :
	reserve_row_count = v
	if _scroll_size_container:
		_scroll_size_container.custom_minimum_size.y = _get_scroll_size_for_row_count(reserve_row_count)

@export var auto_add_columns: = false

@onready var _scroll_size_container = $"%ScrollSizeContainer"
@onready var _scroll_container = $"%ScrollContainer"
@onready var _label = $"%Label"
@onready var _elements: Inventory = $"%Elements"

var player_index: = 0
var _element_size: = Vector2.ZERO

func _ready() -> void :
	_element_size = _elements.element_size
	_elements.display_locked_icon = display_locked_icon
	_elements.display_banned = display_banned
	_elements.item_background_transparency = item_background_transparency
	_elements.item_background_modulate = item_background_modulate
	_elements.player_index = player_index

	if not authorize_sorting:
		if is_instance_valid($"%Sort_Inventory_button"):
			$"%Sort_Inventory_button".hide()
		if is_instance_valid($"%button_reverse_order"):
			$"%button_reverse_order".hide()

	
	_set_reserve_column_count(reserve_column_count)
	_set_reserve_row_count(reserve_row_count)

	var _error = _elements.connect("elements_changed", Callable(self, "_on_size_changed"))
	_error = _scroll_size_container.connect("resized", Callable(self, "_on_size_changed"))
	set_process(true)

	forward_focus_settings_to_inventory()


func _process(_delta: float) -> void :
	
	call_deferred("_on_size_changed")
	set_process(false)


func get_element_count() -> int:
	var count: = 0
	for element in _elements.get_children():
		if not element.is_queued_for_deletion():
			count += 1
	return count


func get_element(index: int) -> InventoryElement:
	var element = _elements.get_child(index)
	if element and not element.is_queued_for_deletion():
		return element
	return null


func set_label(label: String) -> void :
	_label.text = label


func set_data(label: String, category: int, elements: Array, reverse: bool = false, prioritize_gameplay_elements: bool = false) -> void :
	_label.text = label
	_elements.category = category
	_elements.set_elements(elements, reverse, true, prioritize_gameplay_elements)


func focus_element_index(index: int) -> void :
	_elements.focus_element_index(index)


func forward_focus_settings_to_inventory() -> void :
	
	_elements.focus_neighbour_strategy = focus_neighbour_strategy
	_elements.set_neighbour_top = set_neighbour_top
	_elements.set_neighbour_bottom = set_neighbour_bottom
	_elements.set_neighbour_left = set_neighbour_left
	_elements.set_neighbour_right = set_neighbour_right

	_elements.focus_neighbor_top = _get_path_relative_to_elements(focus_neighbor_top)
	_elements.focus_neighbor_bottom = _get_path_relative_to_elements(focus_neighbor_bottom)
	_elements.focus_neighbor_left = _get_path_relative_to_elements(focus_neighbor_left)
	_elements.focus_neighbor_right = _get_path_relative_to_elements(focus_neighbor_right)

	_elements.queue_set_focus_neighbours()


func _on_size_changed() -> void :
	var capacity = _get_capacity(_scroll_size_container)
	var capacity_x = int(capacity.x)
	var capacity_y = int(capacity.y)
	
	var expands_vertically = size_flags_vertical & SIZE_EXPAND
	_scroll_container.custom_minimum_size.y = _get_scroll_size_for_row_count(capacity_y if expands_vertically else reserve_row_count)
	if not auto_add_columns:
		return
	var overflow = int(max(0, get_element_count() - capacity_x * capacity_y))
	
	_elements.columns = capacity_x + (overflow + capacity_y - 1) / capacity_y

	if not Engine.is_editor_hint():
		_elements.queue_set_focus_neighbours()



func _get_capacity(control: Control = self) -> Vector2:
	if _element_size == Vector2.ZERO:
		return Vector2(_elements.columns, _elements.rows)
	var v_separation = _elements.get_theme_constant("v_separation")
	var h_separation = _elements.get_theme_constant("h_separation")

	
	var capacity_rows
	var capacity_columns

	if auto_add_columns:
		capacity_rows = int((control.size.y - v_separation) / (_element_size.y + v_separation))
		capacity_columns = int(control.size.x / (_element_size.x + h_separation))
	else:
		capacity_rows = int(control.size.y / (_element_size.y + v_separation))
		capacity_columns = int((control.size.x - h_separation) / (_element_size.x + h_separation))

	return Vector2(capacity_columns, capacity_rows)


func _get_scroll_size_for_row_count(count: int) -> float:
	var v_separation = _elements.get_theme_constant("v_separation")

	if auto_add_columns:
		return v_separation + (_element_size.y + v_separation) * count
	else:
		
		return (_element_size.y + v_separation) * count - 1


func _get_scroll_size_for_column_count(count: int) -> float:
	var h_separation = _elements.get_theme_constant("h_separation")

	if auto_add_columns:
		return (_element_size.x + h_separation) * count - 1
	else:
		return h_separation + (_element_size.x + h_separation) * count


func _get_path_relative_to_elements(path: NodePath) -> NodePath:
	if path.is_empty():
		return path
	return _elements.get_path_to(get_node(path))


func _on_Elements_elements_changed():
	emit_signal("elements_changed")
