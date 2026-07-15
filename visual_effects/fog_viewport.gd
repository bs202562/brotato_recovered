extends SubViewport
class_name FogViewport

@export var player_light_in_shadow_scene: PackedScene
@export var elemental_light_in_shadow_scene: PackedScene
@export var structure_and_pet_light_in_shadow_scene: PackedScene
@export var fire_light_color: Color

@onready var fog_sprite: Sprite2D = $"%Fog"
@onready var main = get_tree().current_scene
@onready var camera: MyCamera = $"%Camera3D"

var player_lights: Array = []
var fire_lights: Dictionary
var fire_lights_pool: Array = []
var structure_and_pet_lights: Dictionary
var structure_and_pet_lights_pool: Array = []
var explosion_lights: Dictionary
var explosion_lights_pool: Array = []
var _wave_fog_scale: float = 1.0
var _base_fog_scale: Vector2 = Vector2.ZERO
var _player_bonus: Array = []


func _initialize():
	if not main._is_fog_wave:
		fog_sprite.queue_free()
		queue_free()
		return

	size = Vector2i(1920, 1080)
	_base_fog_scale = get_visible_rect().size / Vector2(size)

	fog_sprite.show()
	fog_sprite.centered = true


	for player in RunData.players_data:
		var instance: = player_light_in_shadow_scene.instantiate()
		add_child(instance)
		player_lights.append(instance)

	_change_fog_size(RunData.current_wave)

func _change_fog_size(_wave):
	var _fog_size_scale = 1.0
	if _wave > 20:
		_wave = 20

	_fog_size_scale = 2.75 - 1.75 * (_wave / 20.0)
	_wave_fog_scale = _fog_size_scale

	for i in range(RunData.get_player_count()):
		_player_bonus.push_back(RunData.get_player_effect(Keys.stat_fog_visibility_hash, i) / 100.0)
		player_lights[i].scale = Vector2.ONE * (1.0 + _player_bonus[i])


func _process(_delta):
	# 4.x 移植: 读 camera.zoom_factor(3.x 语义)而非引擎的 camera.zoom(4.x 已反转)
	fog_sprite.scale = _base_fog_scale * _wave_fog_scale * camera.zoom_factor.x
	var scale_factor = fog_sprite.scale.x
	fog_sprite.global_position = camera.global_position

	for light_index in player_lights.size():
		if (player_lights[light_index] == null):
			continue

		player_lights[light_index].scale = Vector2.ONE * (1.0 + _player_bonus[light_index]) / camera.zoom_factor.x
		player_lights[light_index].global_position = (main._players[light_index].global_position - camera.global_position) / scale_factor + (Vector2(size) / 2)
		if (main._players[light_index].dead):
			var instance_to_free = player_lights[light_index]
			remove_child(instance_to_free)
			instance_to_free.queue_free()
			player_lights[light_index] = null
	for particle in fire_lights:
		fire_lights[particle].scale = Vector2.ONE / camera.zoom_factor.x
		fire_lights[particle].global_position = (particle.global_position - camera.global_position) / scale_factor + (Vector2(size) / 2)
	for entity in structure_and_pet_lights:
		structure_and_pet_lights[entity].scale = Vector2.ONE / camera.zoom_factor.x
		structure_and_pet_lights[entity].global_position = (entity.global_position - camera.global_position) / scale_factor + (Vector2(size) / 2)
	for entity in explosion_lights:
		explosion_lights[entity].scale = Vector2.ONE / camera.zoom_factor.x
		explosion_lights[entity].global_position = (entity.global_position - camera.global_position) / scale_factor + (Vector2(size) / 2)


func _on_emit_fire_particle(burning_particle):
	if fire_lights.has(burning_particle):
		return

	var fire_light_instance
	if fire_lights_pool.size() > 0:
		fire_light_instance = fire_lights_pool[0]
		fire_lights_pool.remove_at(0)
	else:
		fire_light_instance = elemental_light_in_shadow_scene.instantiate()
		add_child(fire_light_instance)

	fire_light_instance.modulate = fire_light_color
	fire_lights[burning_particle] = fire_light_instance
	if not burning_particle.is_connected("stop_emitting", Callable(self, "_stop_emiting_fire_particle")):
		burning_particle.connect("stop_emitting", Callable(self, "_stop_emiting_fire_particle"))


func _stop_emiting_fire_particle(burning_particle):
	if not fire_lights.has(burning_particle):
		return

	if burning_particle.is_connected("stop_emitting", Callable(self, "_stop_emiting_fire_particle")):
		burning_particle.disconnect("stop_emitting", Callable(self, "_stop_emiting_fire_particle"))

	var current_light = fire_lights[burning_particle]
	fire_lights.erase(burning_particle)

	var tween = create_tween()
	tween.tween_property(current_light, "modulate", Color(current_light.modulate.r, current_light.modulate.g, current_light.modulate.b, 0), 0.25).from(current_light.modulate)

	await tween.finished
	fire_lights_pool.push_back(current_light)

func _on_spawn_structure_or_pet(entity):
	if structure_and_pet_lights.has(entity):
		return

	var light_instance
	if structure_and_pet_lights_pool.size() > 0:
		light_instance = structure_and_pet_lights_pool[0]
		structure_and_pet_lights_pool.remove_at(0)
	else:
		light_instance = structure_and_pet_light_in_shadow_scene.instantiate()
		add_child(light_instance)

	light_instance.modulate = fire_light_color
	structure_and_pet_lights[entity] = light_instance
	if not "is_scapegoat" in entity and not entity.is_connected("died", Callable(self, "_stop_emiting_structure_or_pet_light")):
		entity.connect("died", Callable(self, "_stop_emiting_structure_or_pet_light"))

func _stop_emiting_structure_or_pet_light(entity, args):
	if not structure_and_pet_lights.has(entity):
		return

	if entity.is_connected("died", Callable(self, "_stop_emiting_structure_or_pet_light")):
		entity.disconnect("died", Callable(self, "_stop_emiting_structure_or_pet_light"))

	var current_light = structure_and_pet_lights[entity]
	structure_and_pet_lights.erase(entity)

	var tween = create_tween()
	tween.tween_property(current_light, "modulate", Color(current_light.modulate.r, current_light.modulate.g, current_light.modulate.b, 0), 0.25).from(current_light.modulate)

	await tween.finished
	structure_and_pet_lights_pool.push_back(current_light)

func _on_spawn_explosion(entity):
	if explosion_lights.has(entity):
		return

	var light_instance
	if explosion_lights_pool.size() > 0:
		light_instance = explosion_lights_pool[0]
		explosion_lights_pool.remove_at(0)
	else:
		light_instance = structure_and_pet_light_in_shadow_scene.instantiate()
		add_child(light_instance)

	light_instance.modulate = fire_light_color
	explosion_lights[entity] = light_instance
	await get_tree().create_timer(0.25).timeout
	_stop_emiting_explosion_light(entity)

func _stop_emiting_explosion_light(entity):
	if not explosion_lights.has(entity):
		return

	var current_light = explosion_lights[entity]
	explosion_lights.erase(entity)

	var tween = create_tween()
	tween.tween_property(current_light, "modulate", Color(current_light.modulate.r, current_light.modulate.g, current_light.modulate.b, 0), 0.25).from(current_light.modulate)

	await tween.finished
	explosion_lights_pool.push_back(current_light)
