class_name ItemDescription
extends VBoxContainer

const SCROLL_SPEED: = 600.0

signal mouse_hovered_category
signal mouse_exited_category

@export var effect_line: PackedScene
@export var expand_indefinitely: bool = true
@export var show_details: bool = true
@export var show_player_stats: bool = false
@export var hide_description_if_locked_in_codex := false
@export var silhouette_locked_items := false

var item: ItemParentData
@onready var icon_panel: Panel = get_node_or_null("%IconPanel")

@onready var _icon: TextureRect = get_node_or_null("HBoxContainer/IconPanel/Icon")
@onready var _name = get_node_or_null("%Name")
@onready var _category = get_node_or_null("%Category")

@onready var _vbox_container = $"%VBoxContainer" as VBoxContainer
@onready var _effects = $"%Effects" as VBoxContainer
@onready var _weapon_stats: RichTextLabel = get_node_or_null("%WeaponStats")
@onready var _player_stat_descr_l: RichTextLabel = get_node_or_null("%PlayerStatsDescr_left")
@onready var _player_stat_descr_r: RichTextLabel = get_node_or_null("%PlayerStatsDescr_right")

@onready var _scroll_container = $"%ScrollContainer"
@onready var _effects_scrolled = $"%Effects_scrolled" as VBoxContainer
@onready var _weapon_stats_scrolled: RichTextLabel = get_node_or_null("%WeaponStats_scrolled")
@onready var _player_stat_descr_scrolled_l: RichTextLabel = get_node_or_null("%PlayerStatsDescr_scrolled_left")
@onready var _player_stat_descr_scrolled_r: RichTextLabel = get_node_or_null("%PlayerStatsDescr_scrolled_right")

var _player_index: = 0


func _ready() -> void :
	_vbox_container.visible = show_details and expand_indefinitely
	_scroll_container.visible = show_details and not expand_indefinitely
	set_process_input(false)

func _process(delta: float) -> void :
	_scroll_container.scroll_vertical += Utils.get_player_rjoy_vector(_player_index).y * SCROLL_SPEED * delta

func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if is_instance_valid(_scroll_container):
			set_process(_scroll_container.visible)

func set_item(item_data: ItemParentData, player_index: int, item_count: = 1) -> void :
	item = item_data
	_player_index = player_index

	icon_panel.set_count(item_count)

	_category.show()

	_name.text = item_data.get_name_text()
	_icon.texture = item_data.get_icon()
	_name.modulate = ItemService.get_color_from_tier(item_data.tier)

	icon_panel._update_stylebox(item_data.is_cursed, item_data.tier)

	get_player_stats( - 1).visible = show_player_stats
	get_player_stats(1).visible = show_player_stats

	if show_player_stats:
		get_player_stats( - 1).text = item_data._get_item_player_stats_description( - 1)
		get_player_stats(1).text = item_data._get_item_player_stats_description(1)


	if item_data is DifficultyData and item_data.effects.size() == 0:
		get_effects().text = item_data.description
	else:
		if item_data._is_locked_in_codex() and hide_description_if_locked_in_codex:
			var quantity_needed: int = item_data.unlock_codex_descr_after_get_it - item_data._get_bought_times()
			_generate_special_description_effects(Text.text("CODEX_NEED_TO_BUY_MORE", [str(quantity_needed)], [Sign.NEGATIVE]), null, true)
		else:
			_generate_description_effects(player_index, item_data.effects, true)
	get_effects().visible = get_effects().get_child_count() > 0

	if item_data is WeaponData:
		if not (hide_description_if_locked_in_codex and item_data._is_locked_in_codex()):
			get_weapon_stats().show()
			get_weapon_stats().text = item_data.get_weapon_stats_text(player_index)
			if get_weapon_stats().text == "":
				get_weapon_stats().hide()
			_category.text = tr(ItemService.get_weapon_sets_text(item_data.sets))
		else:
			get_weapon_stats().hide()
	else:
		get_weapon_stats().hide()
		if item_data is CharacterData:
			_category.text = tr("CHARACTER")
		elif item_data is UpgradeData:
			_category.text = tr("UPGRADE")
			icon_panel._replace_with_positive_color()
		elif item_data is DifficultyData:
			_category.text = tr("DIFFICULTY")
		else:
			var is_pet = item_data.is_pet_item()
			var is_structure = item_data.is_structure_item()
			if item_data.max_nb == 1:
				if is_pet:
					if is_structure:
						_category.text = tr("PET") + ", " + tr("STRUCTURE") + ", " + tr("UNIQUE")
					else:
						_category.text = tr("PET") + ", " + tr("UNIQUE")
				elif is_structure:
					_category.text = tr("STRUCTURE") + ", " + tr("UNIQUE")
				else:
					_category.text = tr("UNIQUE")
			elif item_data.max_nb != - 1 and item_data.max_nb != 0:
				if is_pet:
					if is_structure:
						_category.text = tr("PET") + ", " + tr("STRUCTURE") + ", " + Text.text("LIMITED", [str(RunData.get_nb_item(item_data.my_id_hash, player_index)), str(item_data.max_nb)])
					else:
						_category.text = tr("PET") + ", " + Text.text("LIMITED", [str(RunData.get_nb_item(item_data.my_id_hash, player_index)), str(item_data.max_nb)])
				elif is_structure:
					_category.text = tr("STRUCTURE") + ", " + Text.text("LIMITED", [str(RunData.get_nb_item(item_data.my_id_hash, player_index)), str(item_data.max_nb)])
				else:
					_category.text = Text.text("LIMITED", [str(RunData.get_nb_item(item_data.my_id_hash, player_index)), str(item_data.max_nb)])
			else:
				if is_pet:
					if is_structure:
						_category.text = tr("PET") + ", " + tr("STRUCTURE")
					else:
						_category.text = tr("PET")
				elif is_structure:
					_category.text = tr("STRUCTURE")
				else:
					_category.text = tr("ITEM")

	if silhouette_locked_items and item_data._is_silhouette_in_codex():
		_icon.modulate = Color(0, 0, 0, 1)
		_name.text = "???"
		_category.text = ""
	else:
		_icon.modulate = Color(1, 1, 1, 1)

func _generate_description_effects(player_index, effects: Array, colored: bool = true, activate_tab: bool = true):
	var _effect = get_effects()

	for child in _effect.get_children():
		child.queue_free()

	for effect in effects:
		var line: EffectLine = effect_line.instantiate()
		_effect.add_child(line)
		line._display_effect(player_index, effect, colored, activate_tab)

	if item.tracking_text != "[EMPTY]":
		var line: EffectLine = effect_line.instantiate()
		_effect.add_child(line)
		line._display_special_text(item._get_tracking_text(player_index), null)



func _generate_special_description_effects(text: String, icon: Texture2D = null, locked_item: bool = false):
	var _effect = get_effects()

	for child in _effect.get_children():
		child.queue_free()

	var line: EffectLine = effect_line.instantiate()
	_effect.add_child(line)
	line._display_special_text(text, icon, locked_item)


func set_custom_data(name: String, icon: Resource) -> void :
	_name.text = name
	_name.modulate = Color.WHITE
	_icon.texture = icon
	_category.hide()

	get_weapon_stats().hide()
	get_effects().hide()
	item = null


func get_weapon_stats() -> RichTextLabel:
	return _weapon_stats if expand_indefinitely else _weapon_stats_scrolled


func get_player_stats(side: int = 0) -> RichTextLabel:
	if side <= 0:
		return _player_stat_descr_l if expand_indefinitely else _player_stat_descr_scrolled_l
	else:
		return _player_stat_descr_r if expand_indefinitely else _player_stat_descr_scrolled_r


func get_effects() -> VBoxContainer:
	return _effects if expand_indefinitely else _effects_scrolled


func _on_Category_mouse_entered() -> void :
	emit_signal("mouse_hovered_category")


func _on_Category_mouse_exited() -> void :
	emit_signal("mouse_exited_category")
