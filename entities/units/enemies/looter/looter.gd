extends Enemy
class_name Looter

@export var animation_whistle: String # (String, FILE)
@export var effect_exclamation: String # (String, FILE)

func _ready():
	super._ready() # 4.x 移植: Godot 3 自动调用父类虚函数，4.x 需显式调用
	_whistle_fx()

func respawn():
	super.respawn()
	_whistle_fx()


func _whistle_fx() -> void :
	for player in RunData.get_player_count():
		if RunData.get_player_item(Keys.item_whistle_hash, player) != null:
			var _main: Main = get_tree().current_scene

			var fx: = load(animation_whistle)
			var fx_instance: Node2D = fx.instance()
			_main._players[player].get_child(0).add_child(fx_instance)
			fx_instance.position = Vector2(0, 0)

			var fx_exclamation: = load(effect_exclamation)
			var fx_exclamation_instance: Node2D = fx_exclamation.instance()
			add_child(fx_exclamation_instance)
			fx_exclamation_instance.position = Vector2(0, 0)
			break
