extends Node

# ─── Economy
var sucrose: float = 0.0
var sucrose_per_sec: float = 0.0

# ─── Sucrose-per-second tracking (rolling 5s average, sampled 4x/sec)
var _sps_window: Array[float] = []
var _sps_accum: float = 0.0
var _sps_timer: float = 0.0
const SPS_SAMPLE_INTERVAL: float = 0.25
const SPS_WINDOW_SAMPLES: int = 20

# ─── Colony
var active_colony  = null
var colony_position: Vector2 = Vector2(540, 1200)
var queen_alive: bool = true

# ─── Ant counts — real vs visual
var ant_count: int        = 0
var visual_ant_count: int = 0
const MAX_VISUAL_ANTS: int = 200

# ─── Click influence for rally
var ant_click_influence: int = 1

# ─── Food cache — avoids expensive tree scans per ant
var food_nodes: Array = []

# ─── Floater batching
var _pending_sucrose: float = 0.0
var _floater_timer: float   = 0.0
const FLOATER_INTERVAL: float = 1.0

# ─── Spawn boost
var spawn_multiplier: float = 0

# ─── Boost meter — filled by Royal Jelly, triggers colony buff when full
var boost_fill: float = 0.0
var boost_active: bool = false
var _boost_timer: float = 0.0
const BOOST_DURATION: float = 60.0


func _process(delta: float) -> void:
	# ─── Batch floating numbers
	_floater_timer += delta
	if _floater_timer >= FLOATER_INTERVAL and _pending_sucrose > 0:
		_floater_timer   = 0.0
		_spawn_floater(_pending_sucrose)
		_pending_sucrose = 0.0

	# ─── Boost countdown
	if boost_active:
		_boost_timer -= delta
		if _boost_timer <= 0.0:
			_end_boost()

	# ─── Sucrose-per-second — rolling window
	_sps_timer += delta
	if _sps_timer >= SPS_SAMPLE_INTERVAL:
		_sps_timer = 0.0
		_sps_window.append(_sps_accum)
		_sps_accum = 0.0
		if _sps_window.size() > SPS_WINDOW_SAMPLES:
			_sps_window.pop_front()
		var total := 0.0
		for g in _sps_window:
			total += g
		sucrose_per_sec = total / (_sps_window.size() * SPS_SAMPLE_INTERVAL)


func _spawn_floater(amount: float) -> void:
	var FloatingNumber = load("res://Scripts/Objects/FloatingNumber.gd")
	var node           = Node2D.new()
	node.set_script(FloatingNumber)
	node.position = colony_position + Vector2(randf_range(-30, 30), randf_range(-20, 20))
	get_tree().root.add_child(node)
	node.setup(amount, amount >= 5.0)


func add_sucrose(amount: float) -> void:
	sucrose          += amount
	_pending_sucrose += amount
	_sps_accum       += amount
	EventBus.sucrose_changed.emit(sucrose)


func spend_sucrose(amount: float) -> bool:
	if sucrose >= amount:
		sucrose -= amount
		EventBus.sucrose_changed.emit(sucrose)
		return true
	return false


func set_colony(colony_stats) -> void:
	active_colony = colony_stats
	EventBus.colony_loaded.emit(active_colony)


func register_ant() -> void:
	visual_ant_count += 1


func unregister_ant() -> void:
	visual_ant_count = max(0, visual_ant_count - 1)


func register_food(food: Node2D) -> void:
	food_nodes.append(food)


func unregister_food(food: Node2D) -> void:
	food_nodes.erase(food)


# ─── Boost system
func add_boost(amount: float) -> void:
	if boost_active:
		return
	boost_fill = clamp(boost_fill + amount, 0.0, 1.0)
	EventBus.boost_changed.emit(boost_fill)
	if boost_fill >= 1.0:
		_start_boost()


func _start_boost() -> void:
	boost_active = true
	_boost_timer = BOOST_DURATION
	boost_fill = 1.0
	EventBus.boost_activated.emit()
	for ant in get_tree().get_nodes_in_group("ants"):
		ant.speed *= 2.0


func _end_boost() -> void:
	boost_active = false
	boost_fill = 0.0
	EventBus.boost_changed.emit(boost_fill)
	EventBus.boost_ended.emit()
	for ant in get_tree().get_nodes_in_group("ants"):
		ant.speed *= 0.5


# ─── Prestige — full reset, perks carry forward
func prestige(new_colony_stats) -> void:
	sucrose          = 0.0
	queen_alive      = true
	ant_count        = 0
	visual_ant_count = 0
	spawn_multiplier = 0
	sucrose_per_sec  = 0.0
	_sps_accum       = 0.0
	_sps_window.clear()
	boost_fill       = 0.0
	boost_active     = false
	_boost_timer     = 0.0
	UpgradeManager.reset_levels()
	for ant in get_tree().get_nodes_in_group("ants"):
		ant.queue_free()
	set_colony(new_colony_stats)
	EventBus.sucrose_changed.emit(sucrose)
	EventBus.prestige_triggered.emit(new_colony_stats)
