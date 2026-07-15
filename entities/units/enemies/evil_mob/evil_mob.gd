class_name EvilMob
extends Enemy

@export var textures_evolution: Array = [] # (Array, CompressedTexture2D)
@export var quantity_to_evolve: Array = [] # (Array, int)
@export var decrease_speed_by_evolve: int

@onready var life_bar = $"%LifeBar" as UIProgressBar
var life_bar_y_positions = [ - 60, - 60, - 100]

var gold_count: = 0
var evolution: = 0

func _ready():
	super._ready() # 4.x 移植: Godot 3 自动调用父类虚函数，4.x 需显式调用
	var _error_hp_lifebar = connect("health_updated", Callable(self, "on_health_updated"))

func _on_ItemAttractArea_area_entered(item: Item) -> void :
	if dead:
		return

	var should_attract_item: = item is Gold
	if not should_attract_item:
		return
	var item_already_attracted_by_player: = item.attracted_by != null
	if should_attract_item and not item_already_attracted_by_player:
		item.attracted_by = self

func _on_ItemPickUpArea_area_entered(area: Area2D) -> void :
	if dead:
		return

	if area is Gold:
		var gold = area as Gold
		gold_count += gold.value
		gold.pickup( - 1)

		if evolution + 1 < quantity_to_evolve.size():
			if gold_count >= quantity_to_evolve[evolution + 1]:
				evolve(evolution + 1)


func evolve(newEvolution: int) -> void :
	if newEvolution >= 1:
		if ProgressData.settings.hp_bar_on_bosses:
			if not life_bar.visible:
				life_bar.show()
	life_bar.position.y = life_bar_y_positions[newEvolution]
	evolution = newEvolution
	sprite.texture = textures_evolution[evolution]
	bonus_speed = - (decrease_speed_by_evolve * evolution)
	current_stats.health *= int(1 + (0.5 * evolution))
	max_stats.health *= int(1 + (0.5 * evolution))
	if newEvolution >= 1:
		stats.knockback_resistance = int(0.5 + (0.25 * evolution))

func reset_speed_stat(percent_modifier: int = 0) -> void :
	current_stats.speed = stats.speed
	max_stats.speed = current_stats.speed

func get_stats_value() -> int:
	return int(gold_count * (evolution + 1))

func die(args: = Entity.DieArgs.new()) -> void :
	super.die(args)
	life_bar.hide()


func on_health_updated(_unit: Unit, current_val: int, max_val: int) -> void :
	if ProgressData.settings.hp_bar_on_bosses:
		if not life_bar.visible and evolution >= 1:
			life_bar.show()

		life_bar.update_value(current_val, max_val)
	elif life_bar.visible:
		life_bar.hide()
