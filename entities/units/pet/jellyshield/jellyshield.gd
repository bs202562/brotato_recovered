class_name Jellyshield
extends Entity

@export var radius := 100
@export var rotation_speed := 1

var player_index: = - 1
var _owner_player: Player
var _angle = 0
var _phase = 0


func _ready():
	get_tree().current_scene._pause_menu._menu_options.connect("pet_highlighting_changed", Callable(self, "update_highlight"))
	get_tree().current_scene._pause_menu._menu_options.connect("pet_transparency_changed", Callable(self, "_update_transparency"))
	update_highlight()
	_update_transparency(ProgressData.settings.pet_opacity)


func init_trajectory(id: int, count: int, owner_player: Player) -> void :
	_phase = (2 * PI / count) * id
	_owner_player = owner_player
	player_index = owner_player.player_index


func _physics_process(delta: float) -> void :
	_angle += delta * rotation_speed
	var player_position = _owner_player.global_position
	global_position = Vector2(player_position.x + cos(_angle + _phase) * radius, player_position.y + sin(_angle + _phase) * radius)

func _on_Hurtbox_area_entered(hitbox: Area2D) -> void :
	if hitbox.get_parent() is PlayerProjectile:
		return

	RunData.add_tracked_value(player_index, Keys.item_jellyshield_hash, 1)
	hitbox.notify_hit_something(self, 0)
	_animation_player.play("hit")
	await _animation_player.animation_finished
	_animation_player.play("idle")


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


func _update_transparency(value):
	sprite.modulate.a = value
