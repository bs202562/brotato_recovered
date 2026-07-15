class_name DLCData
extends Resource

@export var my_id: String
var my_id_hash: int = Keys.empty_hash
@export var groups_in_all_zones: Array = [] # (Array, Resource)
@export var backgrounds: Array = [] # (Array, Resource)
@export var zones: Array = [] # (Array, Resource)
@export var characters: Array = [] # (Array, Resource)
@export var items: Array = [] # (Array, Resource)
@export var weapons: Array = [] # (Array, Resource)
@export var challenges: Array = [] # (Array, Resource)
@export var elites: Array = [] # (Array, Resource)
@export var bosses: Array = [] # (Array, Resource)
@export var entities_items: Array = [] # (Array, Resource)
@export var stats: Array = [] # (Array, Resource)
@export var sets: Array = [] # (Array, Resource)
@export var icons: Array = [] # (Array, Resource)
@export var scene_effect_behaviors: Array = [] # (Array, Resource)
@export var enemy_effect_behaviors: Array = [] # (Array, Resource)
@export var player_effect_behaviors: Array = [] # (Array, Resource)
@export var music_tracks: Array = [] # (Array, Resource)
@export var title_screen_backgrounds: Array = [] # (Array, Resource)
@export var translations: Array = [] # (Array, Translation)
@export var translation_keys_needing_operator: Dictionary
@export var translation_keys_needing_percent: Dictionary
@export var tracked_items: Dictionary
var tracked_items_hash: Dictionary


func _init() -> void :
	
	
	if my_id_hash == Keys.empty_hash:
		call_deferred("_generate_hashes")


func _generate_hashes() -> void :
	my_id_hash = Keys.generate_hash(my_id)


func duplicate(subresources: = false) -> Resource:
	var duplication = super.duplicate(subresources)

	if my_id_hash == Keys.empty_hash:
		my_id_hash = Keys.generate_hash(my_id)

	duplication.my_id_hash = self.my_id_hash
	duplication.tracked_items_hash = self.tracked_items_hash.duplicate()

	return duplication


func add_resources():
	_generate_hashes()
	for position in translations:
		TranslationServer.add_translation(position)
	ItemService.add_backgrounds(backgrounds)
	ZoneService.zones.append_array(zones)
	ItemService.characters.append_array(characters)
	ItemService.items.append_array(items)
	ItemService.weapons.append_array(weapons)
	ItemService.elites.append_array(elites)
	ItemService.bosses.append_array(bosses)
	ItemService.stats.append_array(stats)
	ItemService.sets.append_array(sets)
	ItemService.icons.append_array(icons)
	ItemService.title_screen_backgrounds.append_array(title_screen_backgrounds)
	ItemService.entities.append_array(entities_items)

	for weapon in weapons:
		if weapon.add_to_chars_as_starting.size() > 0:
			for character_id in weapon.add_to_chars_as_starting:
				var already_has_starting_weapon = false
				var character_data = ItemService.get_element_safe(ItemService.characters, character_id)
				for starting_weapon in character_data.starting_weapons:
					if starting_weapon.my_id == weapon.my_id:
						already_has_starting_weapon = true

				if not already_has_starting_weapon:
					character_data.starting_weapons.push_back(weapon)

	
	
	for stat in ItemService.stats:
		stat.generate_hashes()

	Utils.reset_stat_keys()
	ChallengeService.challenges.append_array(challenges)
	ChallengeService.set_stat_challenges()
	EffectBehaviorService.scene_effect_behaviors.append_array(scene_effect_behaviors)
	EffectBehaviorService.enemy_effect_behaviors.append_array(enemy_effect_behaviors)
	EffectBehaviorService.player_effect_behaviors.append_array(player_effect_behaviors)
	Text.keys_needing_operator.merge(translation_keys_needing_operator)
	Text.keys_needing_percent.merge(translation_keys_needing_percent)

	
	for tracked_item in tracked_items:
		tracked_items_hash[Keys.generate_hash(tracked_item)] = tracked_items[tracked_item]

	RunData.init_tracked_items.merge(tracked_items_hash)
	ItemService.init_unlocked_pool()


func remove_resources():
	for position in translations:
		TranslationServer.remove_translation(position)
	ItemService.remove_backgrounds(backgrounds)

	for weapon in weapons:
		if weapon.add_to_chars_as_starting.size() > 0:
			for character_id in weapon.add_to_chars_as_starting:
				var character_data = ItemService.get_element_safe(ItemService.characters, character_id)
				character_data.starting_weapons.erase(weapon)

	var _res

	for zone in zones:
		ZoneService.zones.erase(zone)
	for character in characters:
		ItemService.characters.erase(character)
	for item in items:
		ItemService.items.erase(item)
	for weapon in weapons:
		ItemService.weapons.erase(weapon)
	for elite in elites:
		ItemService.elites.erase(elite)
	for boss in bosses:
		ItemService.bosses.erase(boss)
	for stat in stats:
		ItemService.stats.erase(stat)
	for set in sets:
		ItemService.sets.erase(set)
	for icon in icons:
		ItemService.icons.erase(icon)
	for background in title_screen_backgrounds:
		ItemService.title_screen_backgrounds.erase(background)
	for enemy in entities_items:
		ItemService.entities.erase(enemy)
	Utils.reset_stat_keys()
	for challenge in challenges:
		ChallengeService.challenges.erase(challenge)
		ChallengeService.stat_challenges.erase(challenge)
	for scene_effect_behavior in scene_effect_behaviors:
		EffectBehaviorService.scene_effect_behaviors.erase(scene_effect_behavior)
	for enemy_effect_behavior in enemy_effect_behaviors:
		EffectBehaviorService.enemy_effect_behaviors.erase(enemy_effect_behavior)
	for player_effect_behavior in player_effect_behaviors:
		EffectBehaviorService.player_effect_behaviors.erase(player_effect_behavior)
	for key in translation_keys_needing_operator:
		_res = Text.keys_needing_operator.erase(key)
	for key in translation_keys_needing_percent:
		_res = Text.keys_needing_percent.erase(key)
	for tracked_item in tracked_items_hash:
		_res = RunData.init_tracked_items.erase(tracked_item)
	ItemService.init_unlocked_pool()


func update_consumable_to_get(base_consumable_data: ConsumableData) -> ConsumableData:
	return base_consumable_data


func update_item_effects(item: ItemParentData, _player_index: int) -> ItemParentData:
	return item
