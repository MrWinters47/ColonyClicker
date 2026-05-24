extends Node

# ─── Economy
var sucrose: float = 0.0

# ─── Colony
var active_colony  = null
var colony_position: Vector2 = Vector2(540, 1200)
var queen_alive: bool = true

# ─── Ant counts — real vs visual
var ant_count: int        = 0   # real colony size (can be huge)
var visual_ant_count: int = 0   # actual Node2D ants on screen
const MAX_VISUAL_ANTS: int = 150

# ─── Click influence for rally
var ant_click_influence: int = 1

# ─── Food cache — avoids expensive tree scans per ant
var food_nodes: Array = []

# ─── Floater batching
var _pending_sucrose: float = 0.0
var _floater_timer: float   = 0.0
const FLOATER_INTERVAL: float = 2.0

func _process(delta: float) -> void:
	# ─── Batch floating numbers — one every 2 seconds
	_floater_timer += delta
	if _floater_timer >= FLOATER_INTERVAL and _pending_sucrose > 0:
		_floater_timer   = 0.0
		_spawn_floater(_pending_sucrose)
		_pending_sucrose = 0.0

func _spawn_floater(amount: float) -> void:
	# ─── Spawn a floating number at colony position
	var FloatingNumber = load("res://Scripts/Objects/FloatingNumber.gd")
	var node           = Node2D.new()
	node.set_script(FloatingNumber)
	node.position = colony_position + Vector2(randf_range(-30, 30), randf_range(-20, 20))
	get_tree().root.add_child(node)
	node.setup(amount, amount >= 5.0)

func add_sucrose(amount: float) -> void:
	sucrose          += amount
	_pending_sucrose += amount
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
	# ─── Called by visual ants only
	visual_ant_count += 1

func unregister_ant() -> void:
	# ─── Called when visual ant dies
	visual_ant_count  = max(0, visual_ant_count - 1)
	ant_count         = max(0, ant_count - 1)

func register_food(food: Node2D) -> void:
	food_nodes.append(food)

func unregister_food(food: Node2D) -> void:
	food_nodes.erase(food)

func prestige(new_colony_stats) -> void:
	# ─── Full reset on prestige — perks carry (handled elsewhere)
	sucrose           = 0.0
	queen_alive       = true
	ant_count         = 0
	visual_ant_count  = 0
	set_colony(new_colony_stats)
	EventBus.sucrose_changed.emit(sucrose)
	EventBus.prestige_triggered.emit(new_colony_stats)
