extends Enemy
class_name Looter

export (String, FILE) var animation_whistle: String
export (String, FILE) var effect_exclamation: String

func _ready():
	_whistle_fx()

func respawn():
	.respawn()
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
