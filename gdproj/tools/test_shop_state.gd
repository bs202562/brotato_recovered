extends Node

# Run with Godot 3.6: --path <isolated project copy> --no-window
# --audio-driver Dummy res://tools/test_shop_state.tscn
# Use a separate user directory: project autoloads initialize save settings.
var failures = 0

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func _run() -> void:
	var progress = get_tree().get_root().get_node("ProgressData")
	var original_state = progress.saved_run_state
	var shop = load("res://ui/menus/shop/base_shop.gd").new()
	for key in ["reroll_count", "paid_reroll_count", "initial_free_rerolls", "free_rerolls", "item_steals"]:
		progress.saved_run_state = {key: []}
		_check(shop._restore_shop_array(key, [2, 3, 0, 0]) == [2, 3, 0, 0], key + " empty snapshot")
		progress.saved_run_state = {key: [0.0, 7.0]}
		var restored = shop._restore_shop_array(key, [2, 3, 4, 5])
		_check(restored == [0, 7, 4, 5], key + " partial coop snapshot preserves spent counters")
		_check(typeof(restored[1]) == TYPE_INT, key + " JSON number conversion")
		restored[0] = 99
		_check(progress.saved_run_state[key][0] == 0, key + " does not mutate saved state")
		progress.saved_run_state = {key: [1, 2, 3, 4]}
		_check(shop._restore_shop_array(key, [0, 0, 0, 0]) == [1, 2, 3, 4], key + " complete snapshot")
		progress.saved_run_state = {}
		_check(shop._restore_shop_array(key, [2, 3, 0, 0]) == [2, 3, 0, 0], key + " missing field")
		progress.saved_run_state = {key: null}
		_check(shop._restore_shop_array(key, [2, 3, 0, 0]) == [2, 3, 0, 0], key + " invalid field")
	progress.saved_run_state = {"shop_items": [[], [["item", 1]]]}
	var items = shop._restore_shop_array("shop_items", [[], [], [], []])
	_check(items == [[], [["item", 1]], [], []], "preserve sold-out shop and coop items")
	items[1].clear()
	_check(progress.saved_run_state.shop_items[1].size() == 1, "shop items do not alias saved state")
	shop.free()
	progress.saved_run_state = original_state
	print("SHOP_STATE_TESTS: ", "PASS" if failures == 0 else "FAIL")
	get_tree().quit(0 if failures == 0 else 1)
