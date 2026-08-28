class_name PlayerOwnerTargetBehavior
extends TargetBehavior

func update_target():
	_parent.current_target = _parent.players_ref[_parent.player_index]
	if _parent.current_target.dead:
		_parent.current_target = self
