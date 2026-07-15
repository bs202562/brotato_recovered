class_name LootwormTargetBehavior
extends TargetBehavior

signal target_found()
signal target_player()

var _main: Main = null
var _entity_spawner: EntitySpawner = null

func init(parent: Node) -> Node:
	.init(parent)

	if _main == null or _entity_spawner == null:
		_entity_spawner = parent._entity_spawner_ref
		_main = parent._entity_spawner_ref._main
		var error = _main.connect("gold_spawned", self, "on_gold_spawned")
		error = _entity_spawner.connect("neutral_respawned", self, "on_neutral_spawned")

	return self

func update_target():
	var min_dist_squared: int = Utils.LARGE_NUMBER
	var neutral_list = _entity_spawner.neutrals

	if _parent.current_target != null:
		if _parent.current_target is Gold and _parent.current_target.is_connected("picked_up", self, "on_gold_picked_up_by_player"):
			_parent.current_target.disconnect("picked_up", self, "on_gold_picked_up_by_player")
		elif _parent.current_target is Neutral and _parent.current_target.is_connected("died", self, "on_dead_tree"):
			_parent.current_target.disconnect("died", self, "on_dead_tree")
	_parent.current_target = null

	for tree in neutral_list:
		if tree.dead:
			continue
		var dist_squared = global_position.distance_squared_to(tree.global_position)
		if dist_squared < min_dist_squared:
			min_dist_squared = dist_squared
			_parent.current_target = tree

	if _parent.current_target != null and not _parent.current_target.is_connected("died", self, "on_dead_tree"):
		var _error = _parent.current_target.connect("died", self, "on_dead_tree")
		emit_signal("target_found", self)
		return

	min_dist_squared = Utils.LARGE_NUMBER
	var active_golds = _main._active_golds

	for gold in active_golds:
		if gold.already_picked_up:
			continue
		var dist_squared = global_position.distance_squared_to(gold.global_position)
		if dist_squared < min_dist_squared:
			min_dist_squared = dist_squared
			_parent.current_target = gold

	
	if _parent.current_target != null:
		var _error = _parent.current_target.connect("picked_up", self, "on_gold_picked_up_by_player")
		emit_signal("target_found", self)
	else:
		_parent.current_target = self

func on_dead_tree(entity: Entity, _die_args: Entity.DieArgs) -> void :
	_parent.current_target.disconnect("died", self, "on_dead_tree")
	_parent.current_target = null

func on_gold_picked_up_by_player(gold: Node, player_index: int) -> void :
	gold.disconnect("picked_up", self, "on_gold_picked_up_by_player")
	_parent.current_target = null

func on_gold_spawned():
	if _parent.current_target != null:
		if _parent.current_target is Gold and _parent.current_target.is_connected("picked_up", self, "on_gold_picked_up_by_player"):
			_parent.current_target.disconnect("picked_up", self, "on_gold_picked_up_by_player")
		elif _parent.current_target is Neutral and _parent.current_target.is_connected("died", self, "on_dead_tree"):
			_parent.current_target.disconnect("died", self, "on_dead_tree")
	_parent.current_target = null

func on_neutral_spawned(entity: Entity):
	if _parent.current_target != null:
		if _parent.current_target is Gold:
			_parent.current_target.disconnect("picked_up", self, "on_gold_picked_up_by_player")
		elif _parent.current_target is Neutral:
			_parent.current_target.disconnect("died", self, "on_dead_tree")
	_parent.current_target = null
