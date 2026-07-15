class_name ModLoaderOptionsProfile
extends Resource





@export var enable_mods: bool = true
@export var locked_mods = [] # (Array, String)
@export var log_level: = ModLoaderLog.VERBOSITY_LEVEL.DEBUG # (ModLoaderLog.VERBOSITY_LEVEL)
@export var disabled_mods = [] # (Array, String)
@export var allow_modloader_autoloads_anywhere: bool = false
@export var steam_workshop_enabled: bool = false
@export var override_path_to_mods = "" # (String, DIR)
@export var override_path_to_configs = "" # (String, DIR)
@export var override_path_to_workshop = "" # (String, DIR)
@export var ignore_deprecated_errors: bool = false
@export var ignored_mod_names_in_log = [] # (Array, String)
