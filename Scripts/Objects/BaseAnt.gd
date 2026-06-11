class_name BaseAnt
extends Node2D

# =============================================================================
# SIGNALS
# =============================================================================
signal food_delivered

# =============================================================================
# STATE
# =============================================================================
enum State { FORAGING, EATING, RETURNING, DEPOSITING, PAUSED }
var state: State = State.FORAGING
var previous_state: State = State.FORAGING

var _carried_reward: float = 1.0
var _carried_boost: float  = 0.0

var _food_check_timer: float = 0.0
const FOOD_CHECK_INTERVAL: float = 0.1

# =============================================================================
# COLONY INTEGRATION
# =============================================================================
var colony: ColonyManager = null

@onready var pheromones = get_tree().get_first_node_in_group("pheromone_grid")

func setup(colony_manager: ColonyManager) -> void:
	GameManager.register_ant()
	colony = colony_manager
	speed              = min(colony.get_stat("base_speed") * 185.0, 300.0)
	food_detect_radius = colony.get_stat("base_forage_rate") * 40.0
	_defense           = colony.get_stat("base_defense")
	_health            = colony.get_stat("base_health")

# =============================================================================
# TWEAK ZONE
# =============================================================================
var speed: float                  = 185.0
var scurry_acceleration: float    = 5.0
var erraticness: float            = 0.5
var retrieve_time: float          = 4.2
var deposit_time: float           = 1.5

var return_sass_strength: float   = 2.6
var return_sass_frequency: float  = 0.8
var turn_speed_forage: float      = 4.0
var turn_speed_return: float      = 10.0
var wander_strength: float        = 1.8
var noise_frequency: float        = 0.4
var food_detect_radius: float     = 40.0
var food_awareness_radius: float  = 150.0
var colony_arrive_radius: float   = 50.0
var pheromone_drop_interval: float = 0.2

var ant_color: Color      = Color(0.08, 0.06, 0.04)
var leg_color: Color      = Color(0.13, 0.10, 0.07)
var eye_color: Color      = Color(0.85, 0.85, 0.85)
var carrying_color: Color = Color(0.2, 0.7, 0.2)

var walk_cycle_speed: float  = 16.0
var leg_swing_amount: float  = 5.0
var body_bob_amount: float   = 0.6
var body_bob_speed: float    = 2.0

const WORLD_W: float = 1080.0
const WORLD_H: float = 2400.0

# =============================================================================
# INTERNALS
# =============================================================================
var _health: float           = 100.0
var _defense: float          = 5.0
var target_direction: float  = 0.0
var _current_speed: float    = 0.0
var _pause_timer: float      = 0.0
var _wall_cooldown: float    = 0.0
var _eat_timer: float        = 0.0
var _deposit_timer: float    = 0.0
var _target_food: Node2D     = null
var _is_eating: bool         = false
var _carrying_food: bool     = false
var _bob_y: float            = 0.3
var _noise_time: float       = 1.0
var _noise_offset: float     = 0.0
var _vbi_freq_drift: float   = 4.0
var _walk_phase: float       = 0.0
var drop_timer: float        = 0.0

var _is_rallying: bool       = false
var _rally_point: Vector2    = Vector2.ZERO
var _rally_timer: float      = 0.0

var _wander_noise: FastNoiseLite
var _return_noise: FastNoiseLite
var _vbi_noise: FastNoiseLite

# =============================================================================
# OPTIMISATION
# =============================================================================
var _draw_timer: float     = 0.0
const DRAW_INTERVAL: float = 0.1

# =============================================================================
# READY
# =============================================================================
func _ready() -> void:
	_wander_noise           = FastNoiseLite.new()
	_wander_noise.seed      = randi()
	_wander_noise.frequency = noise_frequency
	_return_noise           = FastNoiseLite.new()
	_return_noise.seed      = randi()
	_vbi_noise              = FastNoiseLite.new()
	_vbi_noise.seed         = randi()
	_noise_offset    = randf() * 1000.0
	add_to_group("ants")
	target_direction = randf() * TAU
	queue_redraw()

# =============================================================================
# COMBAT
# =============================================================================
func take_damage(amount: float) -> void:
	var actual = max(amount - _defense, 1.0)
	_health -= actual
	if _health <= 0:
		die()

func die() -> void:
	GameManager.unregister_ant()
	EventBus.ant_died.emit(self)
	queue_free()

func command_to_pos(pos: Vector2) -> void:
	_rally_point = pos
	_is_rallying = true
	_rally_timer = 3.5

# =============================================================================
# PROCESS
# =============================================================================
func _process(delta: float) -> void:
	_noise_time += delta

	_draw_timer += delta
	if _draw_timer >= DRAW_INTERVAL:
		_draw_timer = 0.0
		var vp_rect    = get_viewport_rect()
		var screen_pos = get_global_transform_with_canvas().origin
		if vp_rect.has_point(screen_pos):
			queue_redraw()

	# ── PAUSED ───────────────────────────────────────────────────────────────
	if state == State.PAUSED:
		_pause_timer  -= delta
		_current_speed = lerp(_current_speed, 0.0, 12.0 * delta)
		if _pause_timer <= 0.0:
			state = previous_state
		_apply_movement(delta)
		return

	# ── EATING ───────────────────────────────────────────────────────────────
	if state == State.EATING:
		_is_eating     = true
		_carrying_food = false
		_current_speed = lerp(_current_speed, 0.0, 8.0 * delta)
		_eat_timer    -= delta
		if _eat_timer <= 0.0:
			if is_instance_valid(_target_food) and _target_food.has_method("bite"):
				_target_food.bite()
			_target_food = null
			_is_eating   = false
			state        = State.RETURNING
		_apply_movement(delta)
		return

	# ── DEPOSITING ───────────────────────────────────────────────────────────
	if state == State.DEPOSITING:
		_deposit_timer -= delta
		_current_speed  = lerp(_current_speed, 0.0, 10.0 * delta)
		var t           = clamp(1.0 - (_deposit_timer / deposit_time), 0.0, 1.0)
		scale           = Vector2.ONE * (1.0 - t * 0.85)
		if _deposit_timer <= 0.0:
			state    = State.FORAGING
			scale    = Vector2.ONE
			position = GameManager.colony_position + Vector2(randf_range(-30, 30), randf_range(-10, 10))
		_apply_movement(delta)
		return

	_is_eating = false
	_apply_vbi(delta)

	# ─── Random pause
	if randf() < erraticness * 0.008 and not _is_rallying:
		previous_state = state
		state          = State.PAUSED
		_pause_timer   = randf_range(0.05, 0.1 + erraticness * 0.8)

	# ─── Walk animation
	if _current_speed > 5.0:
		var stride_drift = 1.0 + _vbi_noise.get_noise_1d(_noise_time * 0.5 + _noise_offset + 300.0) * 0.4 * erraticness
		_walk_phase     += delta * walk_cycle_speed * (_current_speed / speed) * stride_drift
		if _walk_phase > TAU:
			_walk_phase -= TAU

	# ── FORAGING ─────────────────────────────────────────────────────────────
	if state == State.FORAGING:
		_carrying_food = false
		_current_speed = lerp(_current_speed, speed, scurry_acceleration * delta)

		if _is_rallying:
			_rally_timer -= delta
			var angle_to_click = position.angle_to_point(_rally_point)
			var swarm_noise    = _wander_noise.get_noise_1d(_noise_time + _noise_offset) * 0.4
			target_direction   = angle_to_click + swarm_noise
			rotation           = lerp_angle(rotation, target_direction, turn_speed_forage * 1.8 * delta)
			if _rally_timer <= 0.0:
				_is_rallying = false
		else:
			var noise_val    = _wander_noise.get_noise_1d(_noise_time + _noise_offset)
			target_direction += noise_val * wander_strength * delta
			rotation          = lerp_angle(rotation, target_direction, turn_speed_forage * delta)

		_food_check_timer += delta
		if _food_check_timer >= FOOD_CHECK_INTERVAL:
			_food_check_timer = 0.0
			_check_for_food(delta)

		if pheromones:
			pheromones.deposit(global_position, 5.0)

	# ── RETURNING ────────────────────────────────────────────────────────────
	elif state == State.RETURNING:
		_carrying_food = true
		_is_rallying   = false
		_current_speed = lerp(_current_speed, speed * 1.2, scurry_acceleration * delta)

		var colony_pos      = GameManager.colony_position
		var dist_to_colony  = position.distance_to(colony_pos)
		var wiggle_scale    = clamp(dist_to_colony / 300.0, 0.0, 1.0)
		var angle_to_colony = position.angle_to_point(colony_pos)
		var wiggle          = _return_noise.get_noise_1d(_noise_time + _noise_offset) * return_sass_strength * wiggle_scale
		rotation            = lerp_angle(rotation, angle_to_colony + wiggle, turn_speed_return * delta)

		drop_timer += delta
		if drop_timer >= pheromone_drop_interval:
			drop_timer = 0.0

		if dist_to_colony < colony_arrive_radius:
			state          = State.DEPOSITING
			_deposit_timer = deposit_time
			_carrying_food = false
			food_delivered.emit()
			GameManager.add_sucrose(_carried_reward)
			if _carried_boost > 0.0:
				GameManager.add_boost(_carried_boost)
				_carried_boost = 0.0

	_apply_movement(delta)

# =============================================================================
# MOVEMENT
# =============================================================================
func _apply_vbi(delta: float) -> void:
	var flutter      = _vbi_noise.get_noise_1d(_noise_time * 3.0 + _noise_offset) * 28.0 * erraticness
	_current_speed   = clamp(_current_speed + flutter * delta, speed * 0.5, speed * 2.2)
	var drift        = _vbi_noise.get_noise_1d(_noise_time * 1.3 + _noise_offset + 100.0) * 0.25 * erraticness
	target_direction += drift * delta
	_vbi_freq_drift  = lerp(
		_vbi_freq_drift,
		_vbi_noise.get_noise_1d(_noise_time * 0.15 + _noise_offset + 200.0) * 0.18 * erraticness,
		0.8 * delta
	)
	_wander_noise.frequency = clamp(noise_frequency + _vbi_freq_drift, 0.05, 1.2)
	var jitter  = _vbi_noise.get_noise_1d(_noise_time * 9.0 + _noise_offset + 400.0) * 0.06 * erraticness
	rotation   += jitter

func _apply_movement(delta: float) -> void:
	_bob_y         = sin(_walk_phase * body_bob_speed) * body_bob_amount
	position      += Vector2.RIGHT.rotated(rotation) * _current_speed * delta
	_wall_cooldown -= delta

	if position.x < 20.0 or position.x > WORLD_W - 20.0:
		if _wall_cooldown <= 0.0:
			target_direction = PI - target_direction
			_wall_cooldown   = 0.25
		position.x = clamp(position.x, 21.0, WORLD_W - 21.0)

	if position.y < 20.0 or position.y > WORLD_H - 20.0:
		if _wall_cooldown <= 0.0:
			target_direction = -target_direction
			_wall_cooldown   = 0.25
		position.y = clamp(position.y, 21.0, WORLD_H - 21.0)

func _check_for_food(delta: float) -> void:
	var closest_food: Node2D = null
	var closest_dist: float  = food_awareness_radius
	for food in GameManager.food_nodes:
		if not is_instance_valid(food):
			continue
		var dist = global_position.distance_to(food.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_food = food
	if closest_food == null:
		return
	if closest_dist < food_detect_radius:
		_target_food = closest_food
		if not is_instance_valid(_target_food):
			return
		_eat_timer      = randf_range(retrieve_time * 0.8, retrieve_time * 1.3) * _target_food.retrieve_time_mult
		_carried_reward = _target_food.sucrose_reward
		_carried_boost  = _target_food.boost_value
		state           = State.EATING
		return
	# ─── Pull ant toward food as it gets closer
	var pull_strength = 1.0 - (closest_dist / food_awareness_radius)
	var angle_to_food = global_position.angle_to_point(closest_food.global_position)
	target_direction  = lerp_angle(target_direction, angle_to_food, pull_strength * 0.15)
	rotation          = lerp_angle(rotation, target_direction, turn_speed_forage * 2.0 * delta)
	_wander_noise.frequency = clamp(noise_frequency * (1.0 - pull_strength), 0.02, noise_frequency)

# =============================================================================
# DRAWING
# =============================================================================
func _draw() -> void:
	var eat_pulse: float  = (sin(_noise_time * 6.0) * 0.5 + 0.5) * 0.7
	var carry_lerp: float = 0.35 if _carrying_food else 0.0
	var eat_lerp: float   = eat_pulse if _is_eating else 0.0
	var bc = ant_color.lerp(Color(1.0, 0.78, 0.1, 1.0), eat_lerp).lerp(carrying_color, carry_lerp)
	var lc = leg_color.lerp(carrying_color, 0.2 if _carrying_food else 0.0)
	var bob = Vector2(0, _bob_y)

	var pa = sin(_walk_phase) * leg_swing_amount
	var pb = -sin(_walk_phase) * leg_swing_amount

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

	var sway: float = sin(_walk_phase * 0.5) * 3.0
	var ant_base    = Vector2(13, 0) + bob

	draw_line(ant_base, Vector2(19, -8 + sway), lc, 1.5)
	draw_line(Vector2(19, -8 + sway), Vector2(24, -13 + sway * 1.5), lc, 1.2)
	draw_circle(Vector2(24, -13 + sway * 1.5), 1.4, lc)
	draw_line(ant_base, Vector2(19, 8 - sway), lc, 1.5)
	draw_line(Vector2(19, 8 - sway), Vector2(24, 13 - sway * 1.5), lc, 1.2)
	draw_circle(Vector2(24, 13 - sway * 1.5), 1.4, lc)

	var jaw_open: float = 3.0 if state == State.FORAGING else 1.0
	draw_line(Vector2(14, 0) + bob, Vector2(19, -jaw_open) + bob, bc.lightened(0.2), 1.5)
	draw_line(Vector2(14, 0) + bob, Vector2(19, jaw_open) + bob,  bc.lightened(0.2), 1.5)

	if _carrying_food:
		draw_circle(Vector2(-12, -6) + bob,   3.5, Color(0.2, 0.75, 0.25, 0.95))
		draw_circle(Vector2(-11, -7.5) + bob, 1.2, Color(0.5, 1.0, 0.5, 0.7))

func _draw_leg(attach: Vector2, tip_dir: Vector2, phase: float, color: Color) -> void:
	var tip  = tip_dir + Vector2(phase, 0)
	var knee = (attach + tip) / 2.0 + Vector2(0, tip_dir.y * 0.25)
	draw_line(attach, knee, color, 1.2)
	draw_line(knee, tip,   color, 1.0)
