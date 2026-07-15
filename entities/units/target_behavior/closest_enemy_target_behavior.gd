class_name ClosestEnemyTargetBehavior
extends TargetBehavior

signal target_found()
signal target_player()

@export var target_player_if_no_target := false
@export var pet_id := ""
@export var exclude_elite_and_boss_target := false

var _targets_in_range: = []
var _pet_id_hash: int = 0

func init(parent: Node) -> Node:
	super.init(parent)

	_pet_id_hash = pet_id.hash()
	return self

func update_target():
	var min_dist_squared: int = Utils.LARGE_NUMBER

	if _parent.current_target != null:
		if _parent.current_target.is_connected("died", Callable(self, "on_current_target_died")):
			_parent.current_target.disconnect("died", Callable(self, "on_current_target_died"))
		if _parent.current_target.has_signal("charmed") and _parent.current_target.is_connected("charmed", Callable(self, "on_current_target_charmed")):
			_parent.current_target.disconnect("charmed", Callable(self, "on_current_target_charmed"))
		PetService.remove_target_for_pet(_parent.current_target, _pet_id_hash)

	_parent.current_target = null
	for target in _targets_in_range:
		if target.dead:
			continue
		var dist_squared = global_position.distance_squared_to(target.global_position)
		if dist_squared < min_dist_squared and can_target(target):
			min_dist_squared = dist_squared
			_parent.current_target = target

	if _parent.current_target == null:
		for enemy in _parent._entity_spawner_ref.get_all_enemies(false):
			if can_target(enemy):
				_parent.current_target = enemy
				break

	if not is_instance_valid(_parent.current_target):
		_parent.current_target = null

	if _parent.current_target != null:
		PetService.add_target_for_pet(_parent.current_target, _pet_id_hash)
		if _parent.current_target != null:
			if not _parent.current_target.is_connected("died", Callable(self, "on_current_target_died")):
				var _error = _parent.current_target.connect("died", Callable(self, "on_current_target_died"))
			if not _parent.current_target.is_connected("charmed", Callable(self, "on_current_target_charmed")):
				var _error = _parent.current_target.connect("charmed", Callable(self, "on_current_target_charmed"))
		emit_signal("target_found", self)
	elif target_player_if_no_target:
		_parent.current_target = _parent.players_ref[_parent.player_index]
		emit_signal("target_player", self)

func can_target(target: Node2D) -> bool:
	if target is Boss:
		return not exclude_elite_and_boss_target
	else:
		return not PetService.has_target_for_pet(target, _pet_id_hash)

func _on_Range_body_entered(body: Node2D):
	if _targets_in_range.size() <= 0 and _parent.current_target != null:
		PetService.remove_target_for_pet(_parent.current_target, _pet_id_hash)
		_parent.current_target = null

	_targets_in_range.push_back(body)
	if not body.is_connected("died", Callable(self, "on_current_target_died")):
		var _error = body.connect("died", Callable(self, "on_target_died"))
	if not body.is_connected("charmed", Callable(self, "on_current_target_charmed")):
		var _error = body.connect("charmed", Callable(self, "on_target_charmed"))
	if _parent.current_target == null:
		update_target()


func _on_Range_body_exited(body: Node2D):
	_targets_in_range.erase(body)
	if body.is_connected("died", Callable(self, "on_target_died")):
		body.disconnect("died", Callable(self, "on_target_died"))
	if body.is_connected("charmed", Callable(self, "on_target_charmed")):
		body.disconnect("charmed", Callable(self, "on_target_charmed"))

func on_target_died(target: Node2D, _args: Entity.DieArgs) -> void :
	_targets_in_range.erase(target)
	if target.is_connected("died", Callable(self, "on_target_died")):
		target.disconnect("died", Callable(self, "on_target_died"))
	if target.is_connected("charmed", Callable(self, "on_target_charmed")):
		target.disconnect("charmed", Callable(self, "on_target_charmed"))

func on_target_charmed(target: Node2D) -> void :
	_targets_in_range.erase(target)
	if target.is_connected("died", Callable(self, "on_target_died")):
		target.disconnect("died", Callable(self, "on_target_died"))
	if target.is_connected("charmed", Callable(self, "on_target_charmed")):
		target.disconnect("charmed", Callable(self, "on_target_charmed"))

func on_current_target_died(target: Node2D, _args: Entity.DieArgs) -> void :
	if _parent.current_target != null:
		if _parent.current_target.is_connected("died", Callable(self, "on_current_target_died")):
			_parent.current_target.disconnect("died", Callable(self, "on_current_target_died"))
		if _parent.current_target.has_signal("charmed") and _parent.current_target.is_connected("charmed", Callable(self, "on_current_target_charmed")):
			_parent.current_target.disconnect("charmed", Callable(self, "on_current_target_charmed"))
		PetService.remove_target_for_pet(_parent.current_target, _pet_id_hash)
		_parent.current_target = null

func on_current_target_charmed(target: Node2D) -> void :
	if _parent.current_target != null:
		if _parent.current_target.is_connected("died", Callable(self, "on_current_target_died")):
			_parent.current_target.disconnect("died", Callable(self, "on_current_target_died"))
		if _parent.current_target.is_connected("charmed", Callable(self, "on_current_target_charmed")):
			_parent.current_target.disconnect("charmed", Callable(self, "on_current_target_charmed"))
		PetService.remove_target_for_pet(_parent.current_target, _pet_id_hash)
		_parent.current_target = null
