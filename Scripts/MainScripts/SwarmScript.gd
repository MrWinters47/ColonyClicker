class_name AntSwarm
extends Node2D

# =============================================================================
# ONE node updates + draws EVERY ant. 
# OPTIMIZED: Native math, typed arrays, and staggered timers.
# =============================================================================

enum State { FORAGING, EATING, RETURNING, DEPOSITING, PAUSED }

class Ant:
	var pos: Vector2          = Vector2.ZERO
	var rot: float            = 0.0
	var state: int            = 0
	var prev_state: int       = 0
	var speed: float          = 185.0
	var cur_speed: float      = 0.0
	var target_dir: float     = 0.0
	var noise_offset: float   = 0.0
	var noise_time: float     = 1.0
	var walk_phase: float     = 0.0
	var bob_y: float          = 0.3
	var vbi_freq_drift: float = 4.0
	var draw_scale: float     = 1.0
	var food_detect_radius: float    = 40.0
	var food_awareness_radius: float = 150.0
	var eat_timer: float        = 0.0
	var deposit_timer: float    = 0.0
	var pause_timer: float      = 0.0
	var food_check_timer: float = 0.0
	var wall_cooldown: float    = 0.0
	var drop_timer: float       = 0.0
	var target_food: Node2D     = null
	var carried_reward: float   = 1.0
	var carried_boost: float    = 0.0
	var carrying_food: bool     = false
	var is_eating: bool         = false
	var is_rallying: bool       = false
	var rally_point: Vector2    = Vector2.ZERO
	var rally_timer: float      = 0.0

# ─── Shared tunables ───
var scurry_acceleration: float    = 5.0
var erraticness: float            = 0.5
var retrieve_time: float          = 4.2
var deposit_time: float           = 1.5
var return_sass_strength: float   = 2.6
var turn_speed_forage: float      = 4.0
var turn_speed_return: float      = 10.0
var wander_strength: float        = 1.8
var noise_frequency: float        = 0.4
var colony_arrive_radius: float   = 50.0
var pheromone_drop_interval: float = 0.2

var ant_color: Color      = Color(0.08, 0.06, 0.04)
var leg_color: Color      = Color(0.13, 0.10, 0.07)
var eye_color: Color      = Color(0.85, 0.85, 0.85)
var carrying_color: Color = Color(0.2, 0.7, 0.2)

var walk_cycle_speed: float = 16.0
var leg_swing_amount: float = 5.0
var body_bob_amount: float  = 0.6
var body_bob_speed: float   = 2.0

const WORLD_W: float = 1080.0
const WORLD_H: float = 2400.0
const FOOD_CHECK_INTERVAL: float = 0.1

# ─── Base stats ───
var _base_speed: float          = 185.0
var _base_food_detect: float    = 40.0
var _base_food_awareness: float = 150.0
var colony: ColonyManager = null

# ─── Shared state (OPTIMIZED) ───
var _ants: Array[Ant] = [] # Typed array for GDScript speed boost
var _pheromones = null

# =============================================================================
# OPTIMIZED NATIVE MATH (Replaces FastNoiseLite)
# =============================================================================
func _fast_noise(x: float) -> float:
	# Combines two sine waves at irrational frequencies for an organic feel
	return (sin(x) + sin(x * 2.31)) * 0.5

# =============================================================================
# READY
# =============================================================================
func _ready() -> void:
	add_to_group("ant_swarm")
	_pheromones = get_tree().get_first_node_in_group("pheromone_grid")
	EventBus.prestige_triggered.connect(func(_c): _ants.clear())

# =============================================================================
# PUBLIC API
# =============================================================================
func set_colony(colony_ref: ColonyManager) -> void:
	colony = colony_ref
	_refresh_base_stats()

func spawn_ant(spawn_pos: Vector2 = Vector2.INF) -> void:
	if spawn_pos == Vector2.INF:
		spawn_pos = GameManager.colony_position + Vector2(randf_range(-30, 30), randf_range(-10, 10))
	
	var a = Ant.new()
	a.pos                   = spawn_pos
	a.target_dir            = randf() * TAU
	a.rot                   = a.target_dir
	a.noise_offset          = randf() * 1000.0
	a.state                 = State.FORAGING
	a.speed                 = _base_speed
	a.food_detect_radius    = _base_food_detect
	a.food_awareness_radius = _base_food_awareness
	
	# OPTIMIZED: Desync brains so they don't all check food on the exact same frame
	a.food_check_timer      = randf() * FOOD_CHECK_INTERVAL 
	
	_ants.append(a)
	GameManager.register_ant()

func despawn_ant() -> void:
	if _ants.is_empty():
		return
	_ants.pop_back()
	GameManager.unregister_ant()

func get_ant_count() -> int:
	return _ants.size()

func rally_to(pos: Vector2, max_ants: int = -1) -> void:
	var n = 0
	for ant in _ants:
		ant.rally_point = pos
		ant.is_rallying = true
		ant.rally_timer = 3.5
		n += 1
		if max_ants > 0 and n >= max_ants:
			break

func apply_speed_mult(mult: float, cap: float) -> void:
	_base_speed = min(_base_speed * mult, cap)
	for ant in _ants:
		ant.speed = min(ant.speed * mult, cap)

func apply_awareness_mult(mult: float) -> void:
	_base_food_awareness *= mult
	for ant in _ants:
		ant.food_awareness_radius *= mult

func _refresh_base_stats() -> void:
	if colony == null:
		_base_speed = 185.0
		_base_food_detect = 40.0
		_base_food_awareness = 150.0
		return
	_base_speed       = min(colony.get_stat("base_speed") * 185.0, 300.0)
	_base_food_detect = colony.get_stat("base_forage_rate") * 40.0
	_base_food_awareness = 150.0

# =============================================================================
# PROCESS
# =============================================================================
func _process(delta: float) -> void:
	for ant in _ants:
		_update_ant(ant, delta)
	
	# OPTIMIZED: Let Godot draw at your native framerate
	queue_redraw()

func _update_ant(ant: Ant, delta: float) -> void:
	ant.noise_time += delta

	if ant.state == State.PAUSED:
		ant.pause_timer -= delta
		ant.cur_speed = lerp(ant.cur_speed, 0.0, 12.0 * delta)
		if ant.pause_timer <= 0.0:
			ant.state = ant.prev_state
		_apply_movement(ant, delta)
		return

	if ant.state == State.EATING:
		ant.is_eating = true
		ant.carrying_food = false
		ant.cur_speed = lerp(ant.cur_speed, 0.0, 8.0 * delta)
		ant.eat_timer -= delta
		if ant.eat_timer <= 0.0:
			if is_instance_valid(ant.target_food) and ant.target_food.has_method("bite"):
				ant.target_food.bite()
			ant.target_food = null
			ant.is_eating = false
			ant.state = State.RETURNING
		_apply_movement(ant, delta)
		return

	if ant.state == State.DEPOSITING:
		ant.deposit_timer -= delta
		ant.cur_speed = lerp(ant.cur_speed, 0.0, 10.0 * delta)
		var t = clamp(1.0 - (ant.deposit_timer / deposit_time), 0.0, 1.0)
		ant.draw_scale = 1.0 - t * 0.85
		if ant.deposit_timer <= 0.0:
			ant.state = State.FORAGING
			ant.draw_scale = 1.0
			ant.pos = GameManager.colony_position + Vector2(randf_range(-30, 30), randf_range(-10, 10))
		_apply_movement(ant, delta)
		return

	ant.is_eating = false
	_apply_vbi(ant, delta)

	if randf() < erraticness * 0.008 and not ant.is_rallying:
		ant.prev_state = ant.state
		ant.state = State.PAUSED
		ant.pause_timer = randf_range(0.05, 0.1 + erraticness * 0.8)

	if ant.cur_speed > 5.0:
		var stride = 1.0 + _fast_noise(ant.noise_time * 0.5 + ant.noise_offset + 300.0) * 0.4 * erraticness
		ant.walk_phase += delta * walk_cycle_speed * (ant.cur_speed / ant.speed) * stride
		if ant.walk_phase > TAU:
			ant.walk_phase -= TAU

	if ant.state == State.FORAGING:
		ant.carrying_food = false
		ant.cur_speed = lerp(ant.cur_speed, ant.speed, scurry_acceleration * delta)

		if ant.is_rallying:
			ant.rally_timer -= delta
			var angle_to_click = ant.pos.angle_to_point(ant.rally_point)
			var freq = clamp(noise_frequency + ant.vbi_freq_drift, 0.05, 1.2)
			var swarm_noise = _fast_noise((ant.noise_time + ant.noise_offset) * freq * 10.0) * 0.4
			ant.target_dir = angle_to_click + swarm_noise
			ant.rot = lerp_angle(ant.rot, ant.target_dir, turn_speed_forage * 1.8 * delta)
			if ant.rally_timer <= 0.0:
				ant.is_rallying = false
		else:
			var freq = clamp(noise_frequency + ant.vbi_freq_drift, 0.05, 1.2)
			var noise_val = _fast_noise((ant.noise_time + ant.noise_offset) * freq * 10.0)
			ant.target_dir += noise_val * wander_strength * delta
			ant.rot = lerp_angle(ant.rot, ant.target_dir, turn_speed_forage * delta)

		ant.food_check_timer += delta
		if ant.food_check_timer >= FOOD_CHECK_INTERVAL:
			ant.food_check_timer = 0.0
			_check_for_food(ant, delta)

		if _pheromones:
			_pheromones.deposit(ant.pos, 5.0)

	elif ant.state == State.RETURNING:
		ant.carrying_food = true
		ant.is_rallying = false
		ant.cur_speed = lerp(ant.cur_speed, ant.speed * 1.2, scurry_acceleration * delta)
		
		var colony_pos = GameManager.colony_position
		var dist = ant.pos.distance_to(colony_pos)
		var wiggle_scale = clamp(dist / 300.0, 0.0, 1.0)
		var angle_to_colony = ant.pos.angle_to_point(colony_pos)
		var wiggle = _fast_noise((ant.noise_time + ant.noise_offset) * 2.0) * return_sass_strength * wiggle_scale
		
		ant.rot = lerp_angle(ant.rot, angle_to_colony + wiggle, turn_speed_return * delta)
		ant.drop_timer += delta
		
		if ant.drop_timer >= pheromone_drop_interval:
			ant.drop_timer = 0.0
		
		if dist < colony_arrive_radius:
			ant.state = State.DEPOSITING
			ant.deposit_timer = deposit_time
			ant.carrying_food = false
			GameManager.add_sucrose(ant.carried_reward)
			if ant.carried_boost > 0.0:
				GameManager.add_boost(ant.carried_boost)
				ant.carried_boost = 0.0

	_apply_movement(ant, delta)

# =============================================================================
# MOVEMENT
# =============================================================================
func _apply_vbi(ant: Ant, delta: float) -> void:
	var flutter = _fast_noise(ant.noise_time * 3.0 + ant.noise_offset) * 28.0 * erraticness
	ant.cur_speed = clamp(ant.cur_speed + flutter * delta, ant.speed * 0.5, ant.speed * 2.2)
	
	var drift = _fast_noise(ant.noise_time * 1.3 + ant.noise_offset + 100.0) * 0.25 * erraticness
	ant.target_dir += drift * delta
	
	ant.vbi_freq_drift = lerp(
		ant.vbi_freq_drift,
		_fast_noise(ant.noise_time * 0.15 + ant.noise_offset + 200.0) * 0.18 * erraticness,
		0.8 * delta
	)
	
	var jitter = _fast_noise(ant.noise_time * 9.0 + ant.noise_offset + 400.0) * 0.06 * erraticness
	ant.rot += jitter

func _apply_movement(ant: Ant, delta: float) -> void:
	ant.bob_y = sin(ant.walk_phase * body_bob_speed) * body_bob_amount
	ant.pos += Vector2.RIGHT.rotated(ant.rot) * ant.cur_speed * delta
	ant.wall_cooldown -= delta
	
	if ant.pos.x < 20.0 or ant.pos.x > WORLD_W - 20.0:
		if ant.wall_cooldown <= 0.0:
			ant.target_dir = PI - ant.target_dir
			ant.wall_cooldown = 0.25
		ant.pos.x = clamp(ant.pos.x, 21.0, WORLD_W - 21.0)
		
	if ant.pos.y < 20.0 or ant.pos.y > WORLD_H - 20.0:
		if ant.wall_cooldown <= 0.0:
			ant.target_dir = -ant.target_dir
			ant.wall_cooldown = 0.25
		ant.pos.y = clamp(ant.pos.y, 21.0, WORLD_H - 21.0)

func _check_for_food(ant: Ant, delta: float) -> void:
	var closest: Node2D = null
	var closest_dist: float = ant.food_awareness_radius
	
	for food in GameManager.food_nodes:
		if not is_instance_valid(food):
			continue
		var d = ant.pos.distance_to(food.global_position)
		if d < closest_dist:
			closest_dist = d
			closest = food
			
	if closest == null:
		return
		
	if closest_dist < ant.food_detect_radius:
		ant.target_food    = closest
		ant.eat_timer      = randf_range(retrieve_time * 0.8, retrieve_time * 1.3) * closest.retrieve_time_mult
		ant.carried_reward = closest.sucrose_reward
		ant.carried_boost  = closest.boost_value
		ant.state          = State.EATING
		return
		
	var pull = 1.0 - (closest_dist / ant.food_awareness_radius)
	var angle_to_food = ant.pos.angle_to_point(closest.global_position)
	ant.target_dir = lerp_angle(ant.target_dir, angle_to_food, pull * 0.15)
	ant.rot = lerp_angle(ant.rot, ant.target_dir, turn_speed_forage * 2.0 * delta)

# =============================================================================
# DRAWING
# =============================================================================
func _draw() -> void:
	# 1. Calculate the exact rectangular bounds of what the camera can currently see
	var canvas_transform = get_canvas_transform()
	var view_rect = canvas_transform.affine_inverse() * get_viewport_rect()
	
	# 2. Expand the rectangle slightly so ants don't visibly pop in/out at the edges
	view_rect = view_rect.grow(100.0) 

	for ant in _ants:
		# 3. ONLY execute the heavy drawing math if the ant is inside the viewable area
		if view_rect.has_point(ant.pos):
			draw_set_transform(ant.pos, ant.rot, Vector2.ONE * ant.draw_scale)
			_draw_ant(ant)

func _draw_ant(ant: Ant) -> void:
	var eat_pulse = (sin(ant.noise_time * 6.0) * 0.5 + 0.5) * 0.7
	var carry_lerp = 0.35 if ant.carrying_food else 0.0
	var eat_lerp = eat_pulse if ant.is_eating else 0.0
	var bc = ant_color.lerp(Color(1.0, 0.78, 0.1, 1.0), eat_lerp).lerp(carrying_color, carry_lerp)
	var lc = leg_color.lerp(carrying_color, 0.2 if ant.carrying_food else 0.0)
	var bob = Vector2(0, ant.bob_y)
	
	var pa = sin(ant.walk_phase) * leg_swing_amount
	var pb = -sin(ant.walk_phase) * leg_swing_amount

	_draw_leg(Vector2(2, 0) + bob,  Vector2(8, -9),  pa, lc)
	_draw_leg(Vector2(2, 0) + bob,  Vector2(8, 9),   pb, lc)
	_draw_leg(Vector2(-3, 0) + bob, Vector2(2, -11), pb, lc)
	_draw_leg(Vector2(-3, 0) + bob, Vector2(2, 11),  pa, lc)
	_draw_leg(Vector2(-8, 0) + bob, Vector2(-4, -9), pa, lc)
	_draw_leg(Vector2(-8, 0) + bob, Vector2(-4, 9),  pb, lc)

	draw_circle(Vector2(-12, 0) + bob,     8.0, bc)
	draw_circle(Vector2(-14, -3) + bob,    2.5, bc.lightened(0.22))
	draw_circle(Vector2(-4, 0) + bob,      2.2, bc.darkened(0.15))
	draw_circle(Vector2(0, 0) + bob,       5.5, bc)
	draw_circle(Vector2(-1, -2) + bob,     1.5, bc.lightened(0.15))
	draw_circle(Vector2(10, 0) + bob,      5.0, bc)
	draw_circle(Vector2(12, -2.5) + bob,   1.2, eye_color)
	draw_circle(Vector2(12, 2.5) + bob,    1.2, eye_color)
	draw_circle(Vector2(12.4, -2.8) + bob, 0.4, Color(1.0, 0.086, 1.0, 0.702))
	draw_circle(Vector2(12.4, 2.2) + bob,  0.4, Color(1.0, 0.071, 1.0, 0.702))

	var sway = sin(ant.walk_phase * 0.5) * 3.0
	var ant_base = Vector2(13, 0) + bob
	
	draw_line(ant_base, Vector2(19, -8 + sway), lc, 1.5)
	draw_line(Vector2(19, -8 + sway), Vector2(24, -13 + sway * 1.5), lc, 1.2)
	draw_circle(Vector2(24, -13 + sway * 1.5), 1.4, lc)
	draw_line(ant_base, Vector2(19, 8 - sway), lc, 1.5)
	draw_line(Vector2(19, 8 - sway), Vector2(24, 13 - sway * 1.5), lc, 1.2)
	draw_circle(Vector2(24, 13 - sway * 1.5), 1.4, lc)

	var jaw = 3.0 if ant.state == State.FORAGING else 1.0
	draw_line(Vector2(14, 0) + bob, Vector2(19, -jaw) + bob, bc.lightened(0.2), 1.5)
	draw_line(Vector2(14, 0) + bob, Vector2(19, jaw) + bob,  bc.lightened(0.2), 1.5)

	if ant.carrying_food:
		draw_circle(Vector2(-12, -6) + bob,   3.5, Color(0.2, 0.75, 0.25, 0.95))
		draw_circle(Vector2(-11, -7.5) + bob, 1.2, Color(0.5, 1.0, 0.5, 0.7))

func _draw_leg(attach: Vector2, tip_dir: Vector2, phase: float, color: Color) -> void:
	var tip = tip_dir + Vector2(phase, 0)
	var knee = (attach + tip) / 2.0 + Vector2(0, tip_dir.y * 0.25)
	draw_line(attach, knee, color, 1.2)
	draw_line(knee, tip, color, 1.0)
