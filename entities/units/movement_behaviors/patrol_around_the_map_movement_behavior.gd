class_name PatrolAroundTheMapMovementBehavior
extends MovementBehavior

@export var radius_factor := 0.8

var _current_target: Vector2 = Vector2.ZERO
var _center: Vector2 = Vector2.ZERO
var _radius: float = 0.0
var _angle: float = 0.0
var _phase: float = 0.0

func init(parent: Node) -> Node:
	super.init(parent)
	_radius = (ZoneService.get_current_zone_rect().size.y / 2.0) * radius_factor
	_center = ZoneService.get_map_center()
	_phase = randf_range(0.0, 2 * PI)
	return self

func get_movement() -> Vector2:
	return _current_target - _parent.global_position

func _physics_process(delta):
	_angle += (_parent.get_move_speed() / _radius) * delta
	_current_target = _center + Vector2(cos(_angle + _phase), sin(_angle + _phase)) * _radius
