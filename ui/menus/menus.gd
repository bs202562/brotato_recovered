class_name Menus
extends Control

signal menu_page_switched(from, to)
signal codex_closed()

@onready var _main_menu = $MainMenu
@onready var _menu_choose_options = $MenuOptions
@onready var _codex = $MenuCodex

var _current_page: Control


func _ready() -> void :
	var _error_options = _main_menu.connect("options_button_pressed", Callable(self, "on_options_button_pressed"))
	var _error_codex = _main_menu.connect("codex_button_pressed", Callable(self, "on_codex_button_pressed"))
	_error_codex = _codex.connect("codex_closed", Callable(self, "on_codex_closed"))
	var _error_back_choose_options = _menu_choose_options.connect("back_button_pressed", Callable(self, "on_options_back_button_pressed"))
	_current_page = _main_menu


func back() -> void :
	if _current_page != _main_menu:
		switch(_current_page, _main_menu)


func reset() -> void :
	if _current_page != _main_menu:
		switch(_current_page, _main_menu)


func on_options_button_pressed() -> void :
	switch(_main_menu, _menu_choose_options)


func on_options_back_button_pressed() -> void :
	switch(_menu_choose_options, _main_menu)


func on_codex_button_pressed() -> void :
	_codex._pop()

func on_codex_closed() -> void :
	emit_signal("codex_closed")


func switch(from: Control, to: Control) -> void :
	to.show()
	to.init()
	from.hide()
	_current_page = to
	emit_signal("menu_page_switched", from, to)
