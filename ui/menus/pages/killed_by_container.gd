extends VBoxContainer
class_name KilledByContainer

@onready var icon_panel: IconPanel = $IconPanel
@onready var label: Label = $enemy_label
@onready var icon: TextureRect = get_node_or_null("IconPanel/Icon")
@export var bulletIcon: Texture2D

var player_index: int = 0

func _draw():
	if RunData._players_die_args.size() <= 0:
		hide()
	else:
		_display(RunData._players_die_args[player_index])

func _display(args: Entity.DieArgs = Utils.default_die_args):
	var from = args.from
	if args.is_bullet_hell:
		icon.texture = bulletIcon
		icon.material = UIService.projectile_material
		label.text = tr("BULLETHELL")
		return
	if not is_instance_valid(from):
		hide()
		return
	if from is Enemy:
		icon.texture = from.stats.icon
		for enemy_item in ItemService.entities:
			if enemy_item.stats == from.stats:
				label.text = tr(enemy_item.name)
	elif from is Player:
		icon.texture = RunData.get_player_character(from.player_index).icon
		if from.player_index == player_index:
			label.text = tr("YOURSELF")
		else:
			label.text = tr(RunData.get_player_character(from.player_index).name)
	elif from is ItemParentData:
		icon.texture = from.icon
		label.text = tr(from.name)
	elif from is Consumable:
		icon.texture = from.icon
		label.text = tr(from.name)
