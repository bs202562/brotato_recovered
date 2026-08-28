class_name Pet
extends Unit

export (bool) var can_be_targeted_by_enemies: = false
export (Resource) var curse_particles
export (bool) var shoot_projectiles: = false

var current_target = null
var player_index = - 1
var _current_target_behavior: TargetBehavior
var curse_particle_instance
var is_cursed: bool = false
var _end_of_wave: bool = false

onready var _target_behavior: = $TargetBehavior

func _ready() -> void :
	_current_target_behavior = _target_behavior
	get_tree().current_scene._pause_menu._menu_options.connect("pet_highlighting_changed", self, "update_highlight")
	get_tree().current_scene._pause_menu._menu_options.connect("pet_transparency_changed", self, "_update_transparency")
	update_highlight()
	_update_transparency(ProgressData.settings.pet_opacity)

	var main: Main = get_tree().current_scene
	main.connect("end_of_the_wave", self, "end_of_wave_callback")


func init(zone_min_pos: Vector2, zone_max_pos: Vector2, p_players_ref: Array = [], entity_spawner_ref = null) -> void :
	.init(zone_min_pos, zone_max_pos, p_players_ref, entity_spawner_ref)

	_target_behavior.init(self)
	init_current_stats()
	update_target()


func _update_transparency(value):
	_animation.modulate.a = value

func should_data_be_reload() -> bool:
	return false

func reload_data():
	pass

func set_current_stats(stats: Array) -> void :
	pass

func get_stats() -> Array:
	return []

func reset_speed_stat(percent_modifier: int = 0) -> void :
	_speed_percent_modifier = percent_modifier

	var factor = max((1 + (Utils.get_capped_stat(Keys.stat_speed_hash, player_index) / 100.0)) as float, 1)
	current_stats.speed = stats.speed * factor
	max_stats.speed = current_stats.speed

func update_data(effect: PetEffect) -> void :
	is_cursed = effect.is_cursed
	if is_cursed:
		curse_particle_instance = curse_particles.instance()
		add_child(curse_particle_instance)
		add_outline(Utils.CURSE_COLOR)

func update_target():
	_current_target_behavior.update_target()

func _physics_process(delta: float) -> void :
	if _end_of_wave:
		return

	if current_target == null:
		update_target()

func die(args: = DieArgs.new()) -> void :
	.die(args)

func update_highlight(_value: bool = true):
	if dead: return

	var value = ProgressData.settings.pet_highlighting
	var highlight_color: Color = CoopService.get_player_color(player_index) if RunData.is_coop_run else Utils.HIGHLIGHT_COLOR
	highlight_color.a = 0.5

	if not value:
		if has_outline(highlight_color):
			remove_outline(highlight_color)
	else:
		if not has_outline(highlight_color):
			add_outline(highlight_color)

func is_catling_gun() -> bool:
	return false

func end_of_wave_callback():
	_end_of_wave = true
	_can_pet()

func _can_pet():
	pass

func _check_can_be_pet() -> bool:
	if dead: return false
	var main: Main = get_tree().current_scene
	if main._players[player_index].dead:
		return false
	if global_position.distance_squared_to(main._players[player_index].global_position) < 110 * 110:
		return true
	return false
