class_name EntityBirth
extends Area2D

signal birth_timeout(birth)

const FLICKER_TRANSPARENCY = 0.25

export (float) var time_before_spawn: = 60.0
export (Resource) var birth_begin_sound
export (Resource) var birth_end_sound
export (Texture) var entity_sprite
export (Texture) var structure_sprite

onready var _collision_shape: CollisionShape2D = $"%CollisionShape2D"
onready var _sprite: Sprite = $"%Sprite"

var type: int
var _flicker_cd: float = 0
var _time_invisible: float = 0.0
var _base_color: = Color(ProgressData.settings.color_negative)
var _color: Color = Color(min(1, _base_color.r + 0.22), min(1, _base_color.g + 0.22), min(1, _base_color.b + 0.22), 1.0)
var _colliding_with_player: = false
var _current_time_before_spawn: = 0.0


var scene: PackedScene
var data: Resource
var player_index: int
var source
var charmed_by: int


func start(p_type: int, p_scene: PackedScene, pos: Vector2, p_data: Resource = null, p_player_index: = - 1, p_source = null, p_charmed_by: = - 1) -> void :
	type = p_type
	global_position = pos
	scene = p_scene
	data = p_data
	player_index = p_player_index
	source = p_source
	charmed_by = p_charmed_by

	set_color()
	show()
	set_physics_process(true)
	_collision_shape.call_deferred("set_disabled", false)

	rotation_degrees = rand_range(0, 360)
	_flicker_cd = get_flicker_cd()
	_sprite.modulate = _color
	SoundManager2D.play(birth_begin_sound, global_position, 0, 0.2)
	_current_time_before_spawn = time_before_spawn


func set_color() -> void :
	if charmed_by != - 1:
		_color = Utils.CHARM_COLOR
		_sprite.texture = entity_sprite
	elif type == EntityType.NEUTRAL:
		_color = Color(ProgressData.settings.color_positive)
		_color = Color(min(1, _color.r + 0.22), min(1, _color.g + 0.22), min(1, _color.b + 0.22), 1.0)
		_sprite.texture = entity_sprite
	elif type == EntityType.STRUCTURE or type == EntityType.PET:
		_color = Color.cornflower
		_sprite.texture = structure_sprite
	elif type == EntityType.ENEMY:
		_color = Color(ProgressData.settings.color_negative)
		_color = Color(min(1, _color.r + 0.22), min(1, _color.g + 0.22), min(1, _color.b + 0.22), 1.0)
		_sprite.texture = entity_sprite


func birth() -> void :
	hide()
	set_physics_process(false)
	_collision_shape.set_disabled(true)

	emit_signal("birth_timeout", self)


func get_flicker_cd() -> float:
	return _current_time_before_spawn / 3.25


func _physics_process(delta: float) -> void :
	_current_time_before_spawn -= 60 * delta

	if _sprite.self_modulate.a <= FLICKER_TRANSPARENCY:
		_time_invisible -= 60 * delta

		if _time_invisible <= 0:
			_sprite.self_modulate.a = 1.0
			_flicker_cd = get_flicker_cd()
	else:
		_flicker_cd -= 60 * delta

		if _flicker_cd <= 0:
			_sprite.self_modulate.a = FLICKER_TRANSPARENCY
			_time_invisible = 6

	if _current_time_before_spawn <= 0:

		if _colliding_with_player and type == EntityType.ENEMY:
			global_position = ZoneService.get_rand_pos()
			_current_time_before_spawn = time_before_spawn
		else:
			SoundManager2D.play(birth_end_sound, global_position, - 15, 0.2)
			call_deferred("birth")


func _on_EntityBirth_body_entered(_body: Node) -> void :
	_colliding_with_player = true


func _on_EntityBirth_body_exited(_body: Node) -> void :
	_colliding_with_player = false
