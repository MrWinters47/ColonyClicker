extends Node2D
class_name PheromoneGrid

const CELL := 20
const WORLD := Vector2i(1080, 2400)
const EVAP_RATE := 0.97        # scent kept each tick (closer to 1 = lasts longer → upgrade later)
const EVAP_INTERVAL := 0.1     # fade 10x per second

var cols := WORLD.x / CELL
var rows := WORLD.y / CELL
var food_grid := PackedFloat32Array()
var _evap_accum := 0.0

func _ready() -> void:
	food_grid.resize(cols * rows)

func _process(delta: float) -> void:
	_evap_accum += delta
	if _evap_accum >= EVAP_INTERVAL:
		_evap_accum = 0.0
		evaporate(EVAP_RATE)

func _cell(pos: Vector2) -> Vector2i:
	return Vector2i(int(pos.x / CELL), int(pos.y / CELL))

func _in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < cols and c.y >= 0 and c.y < rows

func deposit(pos: Vector2, amount: float) -> void:
	var c := _cell(pos)
	if _in_bounds(c):
		food_grid[c.y * cols + c.x] += amount

func sample(pos: Vector2) -> float:
	var c := _cell(pos)
	if not _in_bounds(c):
		return 0.0
	return food_grid[c.y * cols + c.x]

func evaporate(rate: float) -> void:
	for i in range(food_grid.size()):
		food_grid[i] *= rate
