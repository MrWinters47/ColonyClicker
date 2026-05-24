extends Node2D

# ─── EXPORTS ──────────────────────────────────────────────────────────────────
@export_group("Economy")
@export var max_food: int = 12

@export_group("Spawn Zone")
@export_range(0.0, 1.0) var min_x: float = 0.1
@export_range(0.0, 1.0) var max_x: float = 0.9
@export_range(0.0, 1.0) var min_y: float = 0.1
@export_range(0.0, 1.0) var max_y: float = 0.7

@export_group("Timing")
@export var respawn_delay: float = 5.0

# ─── INTERNALS ────────────────────────────────────────────────────────────────
const FoodScene = preload("res://Scenes/ObjectScenes/FoodNode.tscn")
var _timer: float = 0.0

func _ready() -> void:
	# Fill world with food immediately on start
	for i in max_food:
		_spawn_food()

func _process(delta: float) -> void:
	# Check every respawn_delay seconds if food needs topping up
	_timer += delta
	if _timer >= respawn_delay:
		_timer = 0.0
		_check_and_spawn()

func _check_and_spawn() -> void:
	# Only spawn if below max
	var current = get_tree().get_nodes_in_group("foods").size()
	if current < max_food:
		_spawn_food()

func _spawn_food() -> void:
	# Spawn at random position within defined zone
	var screen = get_viewport_rect().size
	var food   = FoodScene.instantiate()
	food.position = Vector2(
		randf_range(screen.x * min_x, screen.x * max_x),
		randf_range(screen.y * min_y, screen.y * max_y)
	)
	add_child(food)
