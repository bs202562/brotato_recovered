class_name ClosestNonBurningEnemyTargetBehavior
extends TargetBehavior

signal target_found()
signal target_player()

@export var target_player_if_no_target := false
@export var pet_id := ""

var _targets_in_range: = []
var _pet_id_hash: int = 0

func init(parent: Node) -> Node:
	super.init(parent)

	_pet_id_hash = pet_id.hash()
	return self

func should_update_target() -> bool:
	if _parent.current_target == null or _parent.current_target.dead:
		return true

	if _parent.current_target._is_burning:
		for target in _targets_in_range:
			if not target.dead and not target._is_burning:
				return true

	return false

func update_target():
	var min_dist_squared: int = Utils.LARGE_NUMBER
	var burning_min_dist_squared: int = Utils.LARGE_NUMBER

	if _parent.current_target != null:
		if _parent.current_target.is_connected("died", Callable(self, "on_current_target_died")):
			_parent.current_target.disconnect("died", Callable(self, "on_current_target_died"))
		PetService.remove_target_for_pet(_parent.current_target, _pet_id_hash)

	_parent.current_target = null
	var cache_target = null
	var cache_burning_target = null
	for target in _targets_in_range:
		if target.dead:
			continue
		if target._is_burning:
			var dist_squared = global_position.distance_squared_to(target.global_position)
			if dist_squared < burning_min_dist_squared and can_target(target):
				burning_min_dist_squared = dist_squared
				cache_burning_target = target
		else:
			var dist_squared = global_position.distance_squared_to(target.global_position)
			if dist_squared < min_dist_squared and can_target(target):
				min_dist_squared = dist_squared
				cache_target = target

	if cache_target != null:
		_parent.current_target = cache_target
		PetService.add_target_for_pet(_parent.current_target, _pet_id_hash)
		if not _parent.current_target.is_connected("died", Callable(self, "on_current_target_died")):
			var _error = _parent.current_target.connect("died", Callable(self, "on_current_target_died"))
		emit_signal("target_found", self)
	elif cache_burning_target != null:
		_parent.current_target = cache_burning_target
		PetService.add_target_for_pet(_parent.current_target, _pet_id_hash)
		if not _parent.current_target.is_connected("died", Callable(self, "on_current_target_died")):
			var _error = _parent.current_target.connect("died", Callable(self, "on_current_target_died"))
		emit_signal("target_found", self)
	elif target_player_if_no_target:
		_parent.current_target = _parent.players_ref[_parent.player_index]
		emit_signal("target_player", self)

func can_target(target: Node2D) -> bool:
	return not PetService.has_target_for_pet(target, _pet_id_hash) or (target is Boss and target.is_elite)

func _on_Range_body_entered(body: Node2D):
	if _targets_in_range.size() <= 0 and _parent.current_target != null:
		PetService.remove_target_for_pet(_parent.current_target, _pet_id_hash)
		_parent.current_target = null

	_targets_in_range.push_back(body)
	if not body.is_connected("died", Callable(self, "on_target_died")):
		var _error = body.connect("died", Callable(self, "on_target_died"))
	if _parent.current_target == null:
		update_target()


func _on_Range_body_exited(body: Node2D):
	_targets_in_range.erase(body)
	if body.is_connected("died", Callable(self, "on_target_died")):
		body.disconnect("died", Callable(self, "on_target_died"))

func on_target_died(target: Node2D, _args: Entity.DieArgs) -> void :
	_targets_in_range.erase(target)
	if target.is_connected("died", Callable(self, "on_target_died")):
		target.disconnect("died", Callable(self, "on_target_died"))

func on_current_target_died(target: Node2D, _args: Entity.DieArgs) -> void :
	if _parent.current_target != null:
		if _parent.current_target.is_connected("died", Callable(self, "on_current_target_died")):
			_parent.current_target.disconnect("died", Callable(self, "on_current_target_died"))
		PetService.remove_target_for_pet(_parent.current_target, _pet_id_hash)
		_parent.current_target = null
