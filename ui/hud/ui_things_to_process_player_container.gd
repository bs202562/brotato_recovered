class_name UIThingsToProcessPlayerContainer
extends Control

enum Alignment{BEGIN, END}

@export var horizontal_alignment := Alignment.BEGIN: set = _set_horizontal_alignment
func _set_horizontal_alignment(value):
	horizontal_alignment = value
	_update_layout()

@export var vertical_alignment := Alignment.BEGIN: set = _set_vertical_alignment
func _set_vertical_alignment(value):
	vertical_alignment = value
	_update_layout()


@onready var upgrades: BoxContainer = $"%Upgrades"
@onready var consumables: BoxContainer = $"%Consumables"
@onready var __vbox_container = $"VBoxContainer"


func _ready():
	
	_update_layout()


func _update_layout():
	if upgrades == null:
		
		return
	var left = horizontal_alignment == Alignment.BEGIN
	var top = vertical_alignment == Alignment.BEGIN
	upgrades.alignment = BoxContainer.ALIGNMENT_BEGIN if left else BoxContainer.ALIGNMENT_END
	consumables.alignment = BoxContainer.ALIGNMENT_BEGIN if left else BoxContainer.ALIGNMENT_END
	__vbox_container.grow_horizontal = Control.GROW_DIRECTION_END if left else Control.GROW_DIRECTION_BEGIN
	__vbox_container.alignment = BoxContainer.ALIGNMENT_BEGIN if top else BoxContainer.ALIGNMENT_END
