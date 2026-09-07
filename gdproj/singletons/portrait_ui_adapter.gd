extends Node

var _last_scene_id: int = 0


func _process(_delta: float) -> void:
	var scene = get_tree().current_scene
	if not is_instance_valid(scene):
		return
	if scene.get_instance_id() == _last_scene_id:
		return
	_last_scene_id = scene.get_instance_id()
	call_deferred("_apply_portrait_layout", scene)


func _apply_portrait_layout(scene: Node) -> void:
	if scene is Control:
		_full_rect(scene)
	_fit_named_backgrounds(scene)

	match scene.name:
		"TitleScreen":
			_adapt_title_screen(scene)
		"CharacterSelection":
			_adapt_character_selection(scene)
		"WeaponSelection":
			_adapt_single_player_selection(scene)
		"DifficultySelection":
			_adapt_legacy_selection(scene, 0.55)
		"Shop":
			_adapt_shop(scene)
		"Main":
			_adapt_combat_hud(scene)

	_adapt_embedded_overlays(scene)


func _full_rect(control: Control) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	control.margin_left = 0.0
	control.margin_top = 0.0
	control.margin_right = 0.0
	control.margin_bottom = 0.0


func _fit_named_backgrounds(root: Node) -> void:
	for child in root.get_children():
		if child is TextureRect and str(child.name).find("Background") >= 0:
			_full_rect(child)
			child.expand = true
			child.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_fit_named_backgrounds(child)


func _adapt_title_screen(scene: Node) -> void:
	var menus = scene.get_node_or_null("Menus")
	if menus:
		_full_rect(menus)

	var main_menu = scene.get_node_or_null("Menus/MainMenu")
	if main_menu:
		_full_rect(main_menu)
		var empty_space = main_menu.get_node_or_null("EmptySpace")
		if empty_space:
			empty_space.rect_min_size.y = 860.0
		var button_row = main_menu.get_node_or_null("MarginContainer/VBoxContainer/HBoxContainer")
		if button_row:
			button_row.alignment = BoxContainer.ALIGN_CENTER
		var buttons_left = main_menu.get_node_or_null("MarginContainer/VBoxContainer/HBoxContainer/ButtonsLeft")
		if buttons_left:
			buttons_left.rect_min_size.x = 600.0
			buttons_left.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var buttons_right = main_menu.get_node_or_null("MarginContainer/VBoxContainer/HBoxContainer/ButtonsRight")
		if buttons_right:
			buttons_right.hide()
		var row_spacer = main_menu.get_node_or_null("MarginContainer/VBoxContainer/HBoxContainer/EmptySpace")
		if row_spacer:
			row_spacer.hide()

	# Secondary title pages retain their complete landscape content, scaled into
	# a centered portrait-safe panel with scroll containers remaining interactive.
	for page_name in ["MenuProfile", "MenuOptions", "MenuCodex", "MenuCredits", "MenuMods"]:
		var page = scene.get_node_or_null("Menus/" + page_name)
		if page:
			_fit_legacy_panel(page, 0.55, Vector2(12, 360))


func _adapt_legacy_selection(scene: Node, scale_value: float) -> void:
	var content = scene.get_node_or_null("MarginContainer/VBoxContainer")
	if content:
		content.rect_scale = Vector2(scale_value, scale_value)
		content.rect_position = Vector2(24, 180)
	for suffix in ["2", "3", "4"]:
		var inventory = scene.find_node("Inventory" + suffix, true, false)
		if inventory:
			inventory.hide()
		var panel = scene.find_node("Panel" + suffix, true, false)
		if panel:
			panel.hide()


func _adapt_single_player_selection(scene: Node) -> void:
	var content = scene.get_node_or_null("MarginContainer/VBoxContainer")
	if content:
		content.rect_min_size.x = 960.0
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for suffix in ["2", "3", "4"]:
		var inventory = scene.find_node("Inventory" + suffix, true, false)
		if inventory:
			inventory.hide()
		var panel = scene.find_node("Panel" + suffix, true, false)
		if panel:
			panel.hide()

func _adapt_character_selection(scene: Node) -> void:
	_adapt_legacy_selection(scene,0.88)
	var inventory = scene.find_node("Inventory1",true,false)
	if inventory:
		inventory.columns = 8
		inventory.element_size = Vector2(110,110)
		for element in inventory.get_children():
			if element is Control: element.rect_min_size = Vector2(110,110)
	var content = scene.get_node_or_null("MarginContainer/VBoxContainer")
	if content:
		content.alignment = BoxContainer.ALIGN_BEGIN
		content.rect_min_size = Vector2(1120,0)
	var scroll = scene.find_node("Inventories",true,false)
	if scroll:
		scroll.rect_min_size = Vector2(1000,1000)


func _adapt_shop(scene: Node) -> void:
	var content = scene.get_node_or_null("Content")
	if content:
		_fit_legacy_panel(content, 0.72, Vector2(12, 150))
		content.rect_size = Vector2(1340,2100)
		var margin = content.get_node_or_null("MarginContainer")
		if margin: _full_rect(margin)
	var side_stats = scene.get_node_or_null("Content/MarginContainer/HBoxContainer/VBoxContainer2")
	if side_stats:
		side_stats.rect_min_size.x = 384.0
	var offers = scene.find_node("ShopItemsContainer",true,false)
	if offers:
		for child in offers.get_children():
			if child is Control and str(child.name).begins_with("EmptySpace"): child.hide()
	var gear = scene.find_node("GearContainer",true,false)
	if gear:
		var spacer = gear.get_node_or_null("EmptySpace")
		if spacer: spacer.hide()
		var items = gear.get_node_or_null("ItemsContainer")
		if items: items.reserve_column_count = 4


func _adapt_combat_hud(scene: Node) -> void:
	var hud = scene.get_node_or_null("UI/HUD")
	if not hud:
		return
	_full_rect(hud)
	var life = scene.get_node_or_null("UI/HUD/LifeContainerP1")
	if life:
		life.rect_min_size.x = 400.0
	for bar_path in ["UI/HUD/LifeContainerP1/UILifeBarP1", "UI/HUD/LifeContainerP1/UIXPBarP1"]:
		var bar = scene.get_node_or_null(bar_path)
		if bar:
			bar.rect_min_size.x = 400.0
	var wave = scene.get_node_or_null("UI/HUD/WaveContainer")
	if wave:
		wave.rect_min_size.x = 220.0
	var things = scene.get_node_or_null("UI/HUD/ThingsToProcessMarginContainer")
	if things:
		things.add_constant_override("margin_left", 260)
		things.add_constant_override("margin_right", 260)


func _adapt_embedded_overlays(scene: Node) -> void:
	var pause_menu = scene.find_node("PauseMenu", true, false)
	if pause_menu:
		var pause_menus = pause_menu.get_node_or_null("Menus")
		if pause_menus:
			_fit_legacy_panel(pause_menus, 0.55, Vector2(12, 360))

	var upgrades = scene.find_node("UpgradesUI", true, false)
	if upgrades:
		var upgrade_margin = upgrades.get_node_or_null("MarginContainer")
		if upgrade_margin:
			_fit_legacy_panel(upgrade_margin, 0.55, Vector2(12, 300))


func _fit_legacy_panel(control: Control, scale_value: float, position: Vector2) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.margin_left = 0.0
	control.margin_top = 0.0
	control.rect_scale = Vector2(scale_value, scale_value)
	control.rect_position = position
