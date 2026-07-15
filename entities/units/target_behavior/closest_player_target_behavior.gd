class_name ClosestPlayerTargetBehavior
extends TargetBehavior

func update_target():
	var min_dist_squared: int = Utils.LARGE_NUMBER
	if _parent.current_target != null:
		if _parent.current_target.is_connected("died", Callable(self, "on_current_target_died")):
			_parent.current_target.disconnect("died", Callable(self, "on_current_target_died"))
		_parent.current_target = null

	if _parent.players_ref.size() > _parent.player_index and _parent.players_ref[_parent.player_index] != null:
		var player = _parent.players_ref[_parent.player_index]
		if not player.dead:
			_parent.current_target = player
			var _error = _parent.current_target.connect("died", Callable(self, "on_current_target_died"))
			return

	for player in _parent.players_ref:
		if player.dead:
			continue
		var dist_squared = global_position.distance_squared_to(player.global_position)
		if dist_squared < min_dist_squared:
			min_dist_squared = dist_squared
			_parent.current_target = player

func on_current_target_died(target: Node2D, _args: Entity.DieArgs) -> void :
	if _parent.current_target != null:
		if _parent.current_target.is_connected("died", Callable(self, "on_current_target_died")):
			_parent.current_target.disconnect("died", Callable(self, "on_current_target_died"))
		_parent.current_target = null
