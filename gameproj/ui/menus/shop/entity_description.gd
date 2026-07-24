class_name EntityDescription
extends VBoxContainer

const SCROLL_SPEED: = 600.0

signal mouse_hovered_category
signal mouse_exited_category

export (bool) var expand_indefinitely = true
export (bool) var show_details = true
export (bool) var show_player_stats = false
export (bool) var hide_description_if_locked_in_codex: = false
export (bool) var silhouette_locked_items: = false

var item: ItemParentData
onready var icon_panel: Panel = $"%IconPanel"

onready var _icon = $"%Icon" as TextureRect
onready var _name = $"%Name"
onready var _subtitle = $"%Category"

onready var _vbox_container = $"%VBoxContainer"
onready var _player_stat_descr_l = $"%PlayerStatsDescr_left" as RichTextLabel
onready var _player_stat_descr_r = $"%PlayerStatsDescr_right" as RichTextLabel
onready var _behaviourDesc = $"%BehaviourDesc" as Label

onready var _scroll_container = $"%ScrollContainer" as ScrollContainer
onready var _player_stat_descr_scrolled_l = $"%PlayerStatsDescr_scrolled_left" as RichTextLabel
onready var _player_stat_descr_scrolled_r = $"%PlayerStatsDescr_scrolled_right" as RichTextLabel
onready var _behaviourDesc_scrolled = $"%BehaviourDesc_scrolled" as Label
onready var _screen_text = $"%screen_texture" as TextureRect

onready var info_stats_container: Container = $"%info_stats_container"
onready var graph_hp: WaveGraph = $"%graph_hp"
onready var graph_dammage: WaveGraph = $"%graph_dammage"
onready var graph_armor: WaveGraph = $"%graph_armor"
onready var speed_container: Container = $"%speed_container"
onready var speed_progress_bar: ProgressBar = $"%speed_progress_bar"
onready var speed_label: Label = $"%speed_label"
onready var knoback_resistance_container: Container = $"%knoback_resistance_container"
onready var knoback_resistance_progress_bar: ProgressBar = $"%knoback_resistance_progressbar"
onready var knoback_resistance_label: Label = $"%knoback_resistance_label"
onready var material_dropped_container: Container = $"%material_dropped_container"
onready var material_text_container: Container = $"%material_text_container"
onready var material_label: Label = $"%material_label"

var _player_index: = 0


func _ready() -> void :
	_vbox_container.visible = show_details and expand_indefinitely
	_scroll_container.visible = show_details and not expand_indefinitely
	set_process_input(false)

func _process(delta: float) -> void :
	_scroll_container.scroll_vertical += Utils.get_player_rjoy_vector(_player_index).y * SCROLL_SPEED * delta

func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		set_process(_scroll_container.visible)

func set_item(item_data: ItemEntity, player_index: int, _item_count: = 1) -> void :
	_player_stat_descr_scrolled_l.visible = show_player_stats
	_player_stat_descr_scrolled_r.visible = show_player_stats
	_player_stat_descr_l.visible = show_player_stats
	_player_stat_descr_r.visible = show_player_stats

	item = item_data
	_player_index = player_index

	icon_panel.self_modulate = lerp(ItemService.get_color_from_entity_type(item_data), Color.white, 0.75)
	icon_panel.self_modulate.a = 1

	_name.text = item_data.name
	_behaviourDesc.text = item_data.behaviour_description
	_behaviourDesc_scrolled.text = item_data.behaviour_description
	_icon.texture = item_data.get_icon()
	_name.modulate = ItemService.get_color_from_entity_type(item_data)

	if item_data is ItemPet:
		_subtitle.text = tr("PET")
	elif item_data is ItemEnemy:
		if item_data.is_boss:
			_subtitle.text = tr("BOSS")
		elif item_data.is_elite:
			_subtitle.text = tr("ELITE")
		else:
			_subtitle.text = tr("ENEMY")
	else:
		_subtitle.text = tr("ENTITY")

	get_player_stats( - 1).visible = show_player_stats
	get_player_stats(1).visible = show_player_stats

	if show_player_stats:
		get_player_stats( - 1).bbcode_text = item_data._get_entity_player_stats_description( - 1)
		get_player_stats(1).bbcode_text = item_data._get_entity_player_stats_description(1)

	if silhouette_locked_items and item_data._is_silhouette_in_codex():
		_icon.modulate = Color(0, 0, 0, 1)
		_name.text = "???"
		_behaviourDesc.text = "???"
		_behaviourDesc_scrolled.text = "???"
		info_stats_container.visible = false
		_screen_text.texture = null
	else:
		_icon.modulate = Color(1, 1, 1, 1)
		info_stats_container.visible = false
		_screen_text.texture = item.screen_example

		if item.stats is Stats:
			info_stats_container.visible = true
			graph_hp.visible = item.show_hp
			if item.show_hp:
				var hp_at_20: float = item.stats.health + (item.stats.health_increase_each_wave * 20)
				if hp_at_20 <= 40:
					graph_hp.set_graph(item.stats.health, item.stats.health_increase_each_wave, 40, 1)
				elif hp_at_20 <= 100:
					graph_hp.set_graph(item.stats.health, item.stats.health_increase_each_wave, 100, 1)
				elif hp_at_20 <= 400:
					graph_hp.set_graph(item.stats.health, item.stats.health_increase_each_wave, 400, 1)
				elif hp_at_20 <= 1000:
					graph_hp.set_graph(item.stats.health, item.stats.health_increase_each_wave, 1000, 1)
				elif hp_at_20 <= 4000:
					graph_hp.set_graph(item.stats.health, item.stats.health_increase_each_wave, 4000, 1)
				elif hp_at_20 <= 10000:
					graph_hp.set_graph(item.stats.health, item.stats.health_increase_each_wave, 10000, 1)
				else:
					graph_hp.set_graph(item.stats.health, item.stats.health_increase_each_wave, 40000, 1)
			graph_dammage.visible = item.show_dammage
			if item.show_dammage:
				graph_dammage.set_graph(item.stats.damage, item.stats.damage_increase_each_wave, 40, 1)
			graph_armor.visible = (item.stats.armor + item.stats.armor_increase_each_wave) > 0
			if (item.stats.armor + item.stats.armor_increase_each_wave) > 0:
				graph_armor.set_graph(item.stats.armor, item.stats.armor_increase_each_wave, 20, 1)
			speed_container.visible = item.show_speed
			if item.show_speed:
				speed_progress_bar.value = item.stats.speed
				speed_label.text = str(item.stats.speed)
			knoback_resistance_container.visible = item.show_knoback_resistance
			if item.show_knoback_resistance:
				knoback_resistance_progress_bar.value = item.stats.knockback_resistance * 100
				knoback_resistance_label.text = str(item.stats.knockback_resistance * 100) + "%"
			material_dropped_container.visible = item.show_material_dropped
			if item.show_material_dropped:
				for child_indx in material_text_container.get_child_count():
					material_text_container.get_child(child_indx).visible = child_indx < item.stats.value
				material_label.text = str(item.stats.value)
		else:
			info_stats_container.visible = false


func set_custom_data(name: String, icon: Resource) -> void :
	_name.text = name
	_name.modulate = Color.white
	_icon.texture = icon
	item = null


func get_player_stats(side: int = 0) -> RichTextLabel:
	if side <= 0:
		return _player_stat_descr_l if expand_indefinitely else _player_stat_descr_scrolled_l
	else:
		return _player_stat_descr_r if expand_indefinitely else _player_stat_descr_scrolled_r


func _on_Category_mouse_entered() -> void :
	emit_signal("mouse_hovered_category")


func _on_Category_mouse_exited() -> void :
	emit_signal("mouse_exited_category")
