class_name ClosestMaterialTargetBehavior
extends TargetBehavior

signal target_found()
signal target_player()

var main: Main = null

func init(parent: Node) -> Node:
	super.init(parent)

	if main == null:
		main = parent._entity_spawner_ref._main
		main.connect("gold_spawned", Callable(self, "on_gold_spawned"))

	return self

func update_target():
	var min_dist_squared: int = Utils.LARGE_NUMBER
	var active_golds = main._active_golds

	if _parent.current_target != null:
		_parent.current_target.disconnect("picked_up", Callable(self, "on_gold_picked_up_by_player"))

	_parent.current_target = null
	for gold in active_golds:
		if gold.already_picked_up:
			continue
		var dist_squared = global_position.distance_squared_to(gold.global_position)
		if dist_squared < min_dist_squared:
			min_dist_squared = dist_squared
			_parent.current_target = gold

	
	if _parent.current_target != null:
		var _error = _parent.current_target.connect("picked_up", Callable(self, "on_gold_picked_up_by_player"))
		emit_signal("target_found", self)
	else:
		_parent.current_target = _parent.players_ref[_parent.player_index]
		emit_signal("target_player", self)

func on_gold_picked_up_by_player(gold: Node, player_index: int) -> void :
	gold.disconnect("picked_up", Callable(self, "on_gold_picked_up_by_player"))
	_parent.current_target = null

func on_gold_spawned():
	_parent.current_target = null
