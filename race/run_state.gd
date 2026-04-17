class_name RunState
extends Node

const RUN_STATE_GROUP := &"run_state"
const DEFAULT_STARTING_ROUND_TIME := 30.0

signal round_time_changed(time_remaining: float)
signal lap_time_changed(current_lap_time: float)
signal last_lap_time_changed(last_lap_time: float)
signal multiplier_changed(multiplier: int)
signal currency_changed(currency: int)
signal lap_rewarded(reward: int)
signal round_started(round_number: int)
signal round_finished
signal run_failed(last_round_number: int, final_currency: int)
signal time_bank_cost_changed(cost: int)

@export var lap_tracker_path: NodePath
@export var starting_round_time: float = DEFAULT_STARTING_ROUND_TIME
@export var base_lap_reward: int = 10
@export var starting_multiplier: int = 1
@export var auto_start_run: bool = true
@export var time_bank_base_cost: int = 20
@export var time_bank_cost_increase: int = 20
@export var time_bank_seconds: float = 5.0

var round_number: int = 0
var round_time_remaining: float = 0.0
var current_lap_time: float = 0.0
var last_lap_time: float = 0.0
var current_multiplier: int = 1
var currency: int = 0
var round_earnings: int = 0
var current_time_bank_cost: int = 0
var is_round_active: bool = false
var is_run_over: bool = false

var _lap_tracker: LapTracker = null
var _has_external_clock_driver: bool = false
var _base_starting_round_time: float = DEFAULT_STARTING_ROUND_TIME


func _enter_tree() -> void:
	add_to_group(RUN_STATE_GROUP)


func _ready() -> void:
	_base_starting_round_time = starting_round_time
	_resolve_lap_tracker()
	if auto_start_run and _should_auto_start_run():
		start_run()


func _physics_process(delta: float) -> void:
	if _has_external_clock_driver:
		return
	advance_round_clock(delta)


func start_run() -> void:
	reset_for_new_run()
	start_round()


func reset_for_new_run() -> void:
	currency = 0
	round_number = 0
	starting_round_time = _base_starting_round_time
	current_time_bank_cost = maxi(time_bank_base_cost, 0)
	is_run_over = false
	currency_changed.emit(currency)
	time_bank_cost_changed.emit(current_time_bank_cost)


## Attempts to spend currency for a permanent timer extension. Returns the
## seconds granted (0.0 on failure) and increments the per-run cost when
## successful, so the next purchase is more expensive. Refuses while a round is
## active.
func try_buy_time_bank() -> float:
	if is_round_active:
		return 0.0
	if current_time_bank_cost <= 0 or time_bank_seconds <= 0.0:
		return 0.0
	if not spend_currency(current_time_bank_cost):
		return 0.0

	starting_round_time += time_bank_seconds
	current_time_bank_cost += maxi(time_bank_cost_increase, 0)
	time_bank_cost_changed.emit(current_time_bank_cost)
	return time_bank_seconds


func start_round(extra_start_time: float = 0.0) -> void:
	round_number += 1
	round_time_remaining = maxf(starting_round_time + extra_start_time, 0.0)
	current_lap_time = 0.0
	last_lap_time = 0.0
	current_multiplier = maxi(starting_multiplier, 1)
	round_earnings = 0
	is_round_active = true

	if _lap_tracker:
		_lap_tracker.reset_for_round()
		_lap_tracker.set_tracking_enabled(true)

	round_started.emit(round_number)
	round_time_changed.emit(round_time_remaining)
	lap_time_changed.emit(current_lap_time)
	last_lap_time_changed.emit(last_lap_time)
	multiplier_changed.emit(current_multiplier)
	currency_changed.emit(currency)


func reset_round() -> void:
	start_round()


func add_round_time(seconds: float) -> void:
	if seconds <= 0.0 or not is_round_active:
		return

	round_time_remaining += seconds
	round_time_changed.emit(round_time_remaining)


func advance_round_clock(delta: float) -> void:
	if not is_round_active or delta <= 0.0:
		return

	round_time_remaining = maxf(round_time_remaining - delta, 0.0)
	current_lap_time += delta
	round_time_changed.emit(round_time_remaining)
	lap_time_changed.emit(current_lap_time)

	if is_zero_approx(round_time_remaining):
		_finish_round()


func set_external_clock_driver(is_external: bool) -> void:
	_has_external_clock_driver = is_external


func add_pickup_currency(base_amount: int) -> int:
	var reward: int = maxi(base_amount, 0) * current_multiplier
	_add_currency(reward)
	return reward


func spend_currency(amount: int) -> bool:
	if amount <= 0:
		return false
	if amount > currency:
		return false

	currency -= amount
	currency_changed.emit(currency)
	return true


func _resolve_lap_tracker() -> void:
	_lap_tracker = get_node_or_null(lap_tracker_path) as LapTracker
	if not _lap_tracker:
		push_warning("RunState could not find the lap tracker.")
		return

	if not _lap_tracker.lap_completed.is_connected(_on_lap_completed):
		_lap_tracker.lap_completed.connect(_on_lap_completed)


func _on_lap_completed(_completed_laps: int) -> void:
	if not is_round_active:
		return

	last_lap_time = current_lap_time
	current_lap_time = 0.0
	last_lap_time_changed.emit(last_lap_time)
	lap_time_changed.emit(current_lap_time)

	var reward: int = base_lap_reward * current_multiplier
	_add_currency(reward)
	lap_rewarded.emit(reward)

	current_multiplier += 1
	multiplier_changed.emit(current_multiplier)


func _add_currency(amount: int) -> void:
	if amount <= 0:
		return

	currency += amount
	round_earnings += amount
	currency_changed.emit(currency)


func _finish_round() -> void:
	if not is_round_active:
		return

	is_round_active = false
	if _lap_tracker:
		_lap_tracker.set_tracking_enabled(false)

	var laps_this_round: int = _lap_tracker.completed_laps if _lap_tracker else 0
	if laps_this_round <= 0:
		is_run_over = true
		run_failed.emit(round_number, currency)
		return

	round_finished.emit()


func _should_auto_start_run() -> bool:
	return round_number == 0 \
		and currency == 0 \
		and round_earnings == 0 \
		and current_multiplier == 1 \
		and not is_round_active \
		and is_zero_approx(round_time_remaining) \
		and is_zero_approx(current_lap_time) \
		and is_zero_approx(last_lap_time)
