class_name ModLoaderSetupLog




const MOD_LOG_PATH: = "user://logs/modloader.log"

enum VERBOSITY_LEVEL{
	ERROR, 
	WARNING, 
	INFO, 
	DEBUG, 
}


class ModLoaderLogEntry:
	extends Resource

	var mod_name: String
	var message: String
	var type: String
	var time: String


	func _init(_mod_name: String, _message: String, _type: String, _time: String) -> void :
		mod_name = _mod_name
		message = _message
		type = _type
		time = _time


	func get_entry() -> String:
		return time + get_prefix() + message


	func get_prefix() -> String:
		return "%s %s: " % [type.to_upper(), mod_name]


	func get_md5() -> String:
		return str(get_prefix(), message).md5_text()








static func fatal(message: String, mod_name: String) -> void :
	_log(message, mod_name, "fatal-error")




static func error(message: String, mod_name: String) -> void :
	_log(message, mod_name, "error")




static func warning(message: String, mod_name: String) -> void :
	_log(message, mod_name, "warning")




static func info(message: String, mod_name: String) -> void :
	_log(message, mod_name, "info")




static func success(message: String, mod_name: String) -> void :
	_log(message, mod_name, "success")




static func debug(message: String, mod_name: String) -> void :
	_log(message, mod_name, "debug")




static func debug_json_print(message: String, json_printable, mod_name: String) -> void :
	message = "%s\n%s" % [message, JSON.stringify(json_printable, "  ")]
	_log(message, mod_name, "debug")





static func _log(message: String, mod_name: String, log_type: String = "info") -> void :
	var time: = "%s   " % _get_time_string()
	var log_entry: = ModLoaderLogEntry.new(mod_name, message, log_type, time)

	match log_type.to_lower():
		"fatal-error":
			push_error(message)
			_write_to_log_file(log_entry.get_entry())
			_write_to_log_file(JSON.stringify(get_stack(), "  "))
			assert (false, message)
		"error":
			printerr(message)
			push_error(message)
			_write_to_log_file(log_entry.get_entry())
		"warning":
				print(log_entry.get_prefix() + message)
				push_warning(message)
				_write_to_log_file(log_entry.get_entry())
		"info", "success":
				print(log_entry.get_prefix() + message)
				_write_to_log_file(log_entry.get_entry())
		"debug":
				print(log_entry.get_prefix() + message)
				_write_to_log_file(log_entry.get_entry())






static func _get_time_string() -> String:
	var date_time: = Time.get_datetime_dict_from_system()
	return "%02d:%02d:%02d" % [date_time.hour, date_time.minute, date_time.second]



static func _get_date_string() -> String:
	var date_time: = Time.get_datetime_dict_from_system()
	return "%s-%02d-%02d" % [date_time.year, date_time.month, date_time.day]



static func _get_date_time_string() -> String:
	return "%s_%s" % [_get_date_string(), _get_time_string()]





static func _write_to_log_file(string_to_write: String) -> void :
	if not FileAccess.file_exists(MOD_LOG_PATH):
		_rotate_log_file()

	var log_file := FileAccess.open(MOD_LOG_PATH, FileAccess.READ_WRITE)
	var error: int = OK if log_file != null else FileAccess.get_open_error()
	if not error == OK:
		assert (false, "Could not open log file, error code: %s" % error)
		return

	log_file.seek_end()
	log_file.store_string("\n" + string_to_write)
	log_file.close()




static func _rotate_log_file() -> void :
	var MAX_LOGS: = int(ProjectSettings.get_setting("debug/file_logging/max_log_files"))

	if FileAccess.file_exists(MOD_LOG_PATH):
		if MAX_LOGS > 1:
			var datetime: = _get_date_time_string().replace(":", ".")
			var backup_name: String = MOD_LOG_PATH.get_basename() + "_" + datetime
			if MOD_LOG_PATH.get_extension().length() > 0:
				backup_name += "." + MOD_LOG_PATH.get_extension()

			if DirAccess.dir_exists_absolute(MOD_LOG_PATH.get_base_dir()):
				DirAccess.copy_absolute(MOD_LOG_PATH, backup_name)
			_clear_old_log_backups()

	# 4.x 移植: 全新用户目录下 user://logs 尚不存在，WRITE 模式不会自动建目录
	if not DirAccess.dir_exists_absolute(MOD_LOG_PATH.get_base_dir()):
		DirAccess.make_dir_recursive_absolute(MOD_LOG_PATH.get_base_dir())

	var log_file := FileAccess.open(MOD_LOG_PATH, FileAccess.WRITE)
	var error: int = OK if log_file != null else FileAccess.get_open_error()
	if not error == OK:
		assert (false, "Could not open log file, error code: %s" % error)
	if log_file != null:
		log_file.store_string("%s Created log" % _get_date_string())
		log_file.close()


static func _clear_old_log_backups() -> void :
	var MAX_LOGS: = int(ProjectSettings.get_setting("debug/file_logging/max_log_files"))
	var MAX_BACKUPS: = MAX_LOGS - 1
	var basename: = MOD_LOG_PATH.get_file().get_basename() as String
	var extension: = MOD_LOG_PATH.get_extension() as String

	if not DirAccess.dir_exists_absolute(MOD_LOG_PATH.get_base_dir()):
		return
	var dir := DirAccess.open(MOD_LOG_PATH.get_base_dir())
	if dir == null:
		return

	dir.list_dir_begin()
	var file: = dir.get_next()
	var backups: = []
	while file.length() > 0:
		if ( not dir.current_is_dir() and 
				file.begins_with(basename) and 
				file.get_extension() == extension and 
				not file == MOD_LOG_PATH.get_file()):
			backups.append(file)
		file = dir.get_next()
	dir.list_dir_end()

	if backups.size() > MAX_BACKUPS:
		backups.sort()
		backups.resize(backups.size() - MAX_BACKUPS)
		for file_to_delete in backups:
			dir.remove(file_to_delete)
