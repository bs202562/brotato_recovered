class_name FocusEmulatorBaseData
extends Resource

@export var path: NodePath
@export var apply_player_color := false



@export var contain_horizontal_focus := false

@export var contain_horizontal_focus_exception_paths: Array = [] # (Array, NodePath)

@export var contain_vertical_focus := false


@export var require_entry_from_control_paths: Array = [] # (Array, NodePath)


@export var focus_neighbour_top_paths: Array = [] # (Array, NodePath)
@export var focus_neighbour_bottom_paths: Array = [] # (Array, NodePath)
@export var focus_neighbour_left_paths: Array = [] # (Array, NodePath)
@export var focus_neighbour_right_paths: Array = [] # (Array, NodePath)


func get_focus_neighbour_paths(margin: int) -> Array:
	match margin:
		SIDE_LEFT:
			return focus_neighbour_left_paths
		SIDE_TOP:
			return focus_neighbour_top_paths
		SIDE_RIGHT:
			return focus_neighbour_right_paths
		SIDE_BOTTOM:
			return focus_neighbour_bottom_paths
	return []
