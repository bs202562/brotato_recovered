class_name WanderingBot
extends Turret

var distance = randf_range(100, 200)
var rotation_speed = randf_range(2, 2.5)

var _players: = []
var _angle = randf_range(0, 2 * PI)

@export var slow_sound: Resource


func init(zone_min_pos: Vector2, zone_max_pos: Vector2, players_ref: Array = [], _entity_spawner_ref = null) -> void :
	super.init(zone_min_pos, zone_max_pos, players_ref, _entity_spawner_ref)
	_players = players_ref


func _physics_process(delta: float) -> void :
	_angle += delta * rotation_speed
	var player_position = _players[player_index].global_position
	global_position = Vector2(player_position.x + cos(_angle) * distance, player_position.y + sin(_angle) * distance)

	super._physics_process(delta) # 4.x 移植: Godot 3 自动调用父类虚函数，4.x 需显式调用（_physics_process 为子类优先）


func _on_SlowHitbox_hit_something(thing_hit: Node, _damage_dealt: int) -> void :
	SoundManager2D.play(slow_sound, thing_hit.global_position, - 5, 0.2)
	thing_hit.add_decaying_speed( - 250)
