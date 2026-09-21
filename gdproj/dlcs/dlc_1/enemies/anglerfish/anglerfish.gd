class_name Anglerfish
extends Pursuer

enum State{CHILLING, CHASING, CHARGING, RECOVERING, DECIDING}

const BOOST_CD: float = 60.0
const DELAY_START_TICKING_BOOST_TIMER: float = 30.0

var self_boost_timer: float = 60.0
var delay_start_ticking_self_boost_timer: float = 0.0

var is_in_long_cooldown = false

var initial_max_range = 0
var initial_charge_duration = 0
var initial_charge_speed = 0

var state = State.CHILLING

var recovering_timer: Timer
var deciding_timer: Timer


func _ready():
	initial_max_range = _attack_behavior.max_range
	initial_charge_duration = _attack_behavior.charge_duration
	initial_charge_speed = _attack_behavior.charge_speed

	recovering_timer = create_timer(_attack_behavior.long_cooldown / 60.0, "on_recovering_timer_timeout")
	deciding_timer = create_timer(2.0, "on_deciding_timer_timeout")

	var _e = _attack_behavior.connect("move_unlocked", self, "on_finished_charging")
	_e = _attack_behavior.connect("entered_long_cooldown", self, "on_entered_long_cooldown")
	_e = _movement_behavior.connect("detected_player", self, "on_detected_player")
	_e = _attack_behavior.connect("started_shooting", self, "on_started_charging")

	self_boost_timer = BOOST_CD


func respawn() -> void :
	.respawn()
	state = State.CHILLING
	self_boost_timer = BOOST_CD
	recovering_timer.stop()
	deciding_timer.stop()
	is_in_long_cooldown = false
	_movement_behavior.set_detected(false)


func _physics_process(delta):
	if state != State.CHASING:
		return

	if delay_start_ticking_self_boost_timer >= 0.0:
		delay_start_ticking_self_boost_timer -= 60 * delta
		return

	self_boost_timer -= 60 * delta

	if self_boost_timer <= 0.0:
		boost_self()
		self_boost_timer = BOOST_CD


func switch_state(to_state: int) -> void :
	state = to_state
	match to_state:
		State.CHILLING:
			reset_boost_timers()
			_movement_behavior.set_detected(false)
			reset_attack_data()
		State.CHASING:
			bonus_speed = _movement_behavior.speed_bonus_on_target_detection + nb_times_boosted * speed_on_boost
		State.CHARGING:
			reset_boost_timers()
		State.RECOVERING:
			reset_boost_timers()
			bonus_speed = 0
			recovering_timer.start()
		State.DECIDING:
			reset_boost_timers()
			bonus_speed = 0
			deciding_timer.start()


func on_detected_player() -> void :
	switch_state(State.CHASING)


func on_started_charging() -> void :
	switch_state(State.CHARGING)


func on_entered_long_cooldown() -> void :
	is_in_long_cooldown = true


func on_finished_charging() -> void :

	if state != State.CHARGING:
		return

	if is_in_long_cooldown:
		switch_state(State.RECOVERING)
		is_in_long_cooldown = false
	else:
		switch_state(State.CHASING)


func on_recovering_timer_timeout() -> void :
	if state != State.RECOVERING:
		return
	switch_state(State.CHASING)


func on_deciding_timer_timeout() -> void :
	if state != State.DECIDING:
		return
	switch_state(State.CHILLING)


func reset_boost_timers() -> void :
	delay_start_ticking_self_boost_timer = DELAY_START_TICKING_BOOST_TIMER
	self_boost_timer = BOOST_CD


func _on_hit_something(thing_hit: Node, damage_dealt: int) -> void :
	._on_hit_something(thing_hit, damage_dealt)
	nb_times_boosted = 0
	_attack_behavior._current_cd = 120
	is_in_long_cooldown = false
	_attack_behavior._shots_taken = 0
	_move_locked = false
	reset_attack_data()
	switch_state(State.DECIDING)


func reset_attack_data() -> void :
	reset_boost_timers()
	_attack_behavior.charge_speed = initial_charge_speed
	_attack_behavior.charge_duration = initial_charge_duration
	_attack_behavior.max_range = initial_max_range
	if not dead:
		reset_size()


func boost_self() -> void :
	if not _movement_behavior._detected_player:
		return
	.boost_self()
	_attack_behavior.charge_speed += speed_on_boost * 5
	_attack_behavior.charge_duration += speed_on_boost / 300.0
	_attack_behavior.max_range += speed_on_boost * 2
	is_in_long_cooldown = false
	_attack_behavior._shots_taken = 0


func create_timer(wait_time: float, func_connect_name: String) -> Timer:
	var timer = Timer.new()
	timer.autostart = false
	timer.wait_time = wait_time
	timer.one_shot = true
	var _e = timer.connect("timeout", self, func_connect_name)
	add_child(timer)
	return timer


func state_to_string(p_state: int) -> String:
	match p_state:
		State.CHILLING:
			return "CHILLING"
		State.CHASING:
			return "CHASING"
		State.CHARGING:
			return "CHARGING"
		State.RECOVERING:
			return "RECOVERING"
		State.DECIDING:
			return "DECIDING"

	return "NONE"
