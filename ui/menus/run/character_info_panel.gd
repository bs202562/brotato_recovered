class_name CharacterInfoPanel
extends PanelContainer

@onready var _max_diff_title = $MarginContainer / VBoxContainer / VBoxContainer / VBoxContainer / MaxDifficutlyBeatenTitle
@onready var _max_diff_value = $MarginContainer / VBoxContainer / VBoxContainer / VBoxContainer / MaxDifficultyBeatenValue
@onready var _max_endless_title = $MarginContainer / VBoxContainer / VBoxContainer / VBoxContainer2 / MaxEndlessWaveTitle
@onready var _max_endless_value = $MarginContainer / VBoxContainer / VBoxContainer / VBoxContainer2 / MaxEndlessWaveValue

var character_currently_displayed: String = ""


func set_element(character_id: int) -> void :

	if (character_id == - 1):
		_max_diff_title.text = tr("RANDOM_RECORD_TEXT")
		_max_diff_value.text = ""
		_max_endless_title.text = ""
		_max_endless_value.text = ""
		return

	character_currently_displayed = Keys.hash_to_string[character_id]

	reset_all()

	var character_diff_data = ProgressData.get_character_difficulty_info(character_id, RunData.current_zone, ProgressData.settings.zone_is_random)

	var max_difficulty_data = ItemService.get_element(ItemService.difficulties, Keys.empty_hash, character_diff_data.max_difficulty_beaten.difficulty_value)
	var max_endless_diff_data = ItemService.get_element(ItemService.difficulties, Keys.empty_hash, character_diff_data.max_endless_wave_beaten.difficulty_value)

	if character_diff_data == null or max_difficulty_data == null:
		# 角色从未通关时 difficulty_value 为 -1,难度表中查不到对应项;
		# "NOT_SET" 不在翻译表内会裸显 KEY,保留 reset_all() 的"尚无记录"文案即可
		return

	if character_diff_data.max_difficulty_beaten.difficulty_value != - 1:
		var scaling_text = Utils.get_enemy_scaling_text(
			character_diff_data.max_difficulty_beaten.enemy_health, 
			character_diff_data.max_difficulty_beaten.enemy_damage, 
			character_diff_data.max_difficulty_beaten.enemy_speed, 
			character_diff_data.max_difficulty_beaten.retries, 
			character_diff_data.max_difficulty_beaten.is_coop, 
			character_diff_data.max_difficulty_beaten.used_ban_count, 
			character_diff_data.max_difficulty_beaten.nightmare_proj
		)

		_max_diff_title.text = "MAX_DIFFICULTY_BEATEN"
		_max_diff_value.text = "%s%s" % [Text.text(max_difficulty_data.name, [str(max_difficulty_data.value)]), scaling_text]

	if character_diff_data.max_endless_wave_beaten.wave_number >= 0:
		var scaling_text = Utils.get_enemy_scaling_text(
			character_diff_data.max_endless_wave_beaten.enemy_health, 
			character_diff_data.max_endless_wave_beaten.enemy_damage, 
			character_diff_data.max_endless_wave_beaten.enemy_speed, 
			character_diff_data.max_endless_wave_beaten.retries, 
			character_diff_data.max_endless_wave_beaten.is_coop, 
			character_diff_data.max_endless_wave_beaten.used_ban_count, 
			character_diff_data.max_endless_wave_beaten.nightmare_proj
		)
		_max_endless_title.text = "MAX_ENDLESS_WAVE_BEATEN"
		_max_endless_value.text = "%s - %s%s" % [Text.text("WAVE", [str(character_diff_data.max_endless_wave_beaten.wave_number)]), Text.text(max_endless_diff_data.name, [str(character_diff_data.max_endless_wave_beaten.difficulty_value)]), scaling_text]
	else:
		_max_endless_title.text = ""


func reset_all() -> void :
	_max_diff_title.text = "MAX_DIFFICULTY_BEATEN"
	_max_diff_value.text = "NO_RECORDS_YET"
	_max_endless_title.text = ""
	_max_endless_value.text = ""
