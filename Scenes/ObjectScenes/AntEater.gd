extends Node2D
# =============================================================================
# ANT EATER — the anti-AFK predator.
# Strolls onto the surface, eats any ant it can reach, then leaves. Drives the
# colony Threat Level while it's around. Pure vector movement, procedurally
# drawn — no physics engine, no sprite PNGs. Spawned by GameManager.
# =============================================================================

const WORLD_W: float = 1080.0
const WORLD_H: float = 2400.0

# ─── ⚙️ TWEAK ZONE
const MOVE_SPEED: float   = 140.0   # px/sec while hunting
const TURN_SPEED: float   = 2.5     # how fast it swings toward prey
const EAT_RADIUS: float   = 55.0    # this close = lunch
const AWARE_RADIUS: float = 600.0   # how far it can spot an ant
const MAX_MEALS: int      = 12      # leaves after eating this many…
const MAX_LIFETIME: float = 14.0    # …or after this long, whichever comes first
const EAT_INTERVAL: float = 0.1     # scan for prey 10x/sec

# ─── State
var _heading: float    = 0.0
var _target: Node2D    = null
var _meals: int        = 0
var _lifetime: float   = 0.0
var _eat_timer: float  = 0.0
var _leaving: bool     = false
var _exit_x: float     = 0.0
var _bob: float        = 0.0
var _chomp: float      = 0.0       # brief flash right after a bite
var _walk_phase: float = 0.0

func _ready() -> void:
	z_index = 10  # draw above the ants
	# ─── Enter from a random side, somewhere in the upper play area
	var from_left = randf() < 0.5
	position = Vector2(
		-60.0 if from_left else WORLD_W + 60.0,
		randf_range(WORLD_H * 0.15, WORLD_H * 0.6)
	)
	_heading = 0.0 if from_left else PI
	_exit_x  = -120.0 if from_left else WORLD_W + 120.0
	GameManager.threat_level = GameManager.Threat.HEIGHTENED
	queue_redraw()

func _process(delta: float) -> void:
	_lifetime   += delta
	_bob         = sin(_lifetime * 6.0) * 1.5
	_walk_phase += delta * 8.0
	if _chomp > 0.0:
		_chomp = max(0.0, _chomp - delta * 3.0)

	if _leaving:
		_do_leave(delta)
	else:
		_do_hunt(delta)

	_move(delta)
	queue_redraw()

# =============================================================================
# HUNT
# =============================================================================
func _do_hunt(delta: float) -> void:
	# ─── Time's up or belly's full → head for the hills
	if _lifetime >= MAX_LIFETIME or _meals >= MAX_MEALS:
		_begin_leaving()
		return

	_eat_timer += delta
	if _eat_timer >= EAT_INTERVAL:
		_eat_timer = 0.0
		_target = _nearest_ant()
		# ─── Surface is empty (e.g. you recalled everyone) → nothing to eat, leave
		if _target == null and GameManager.visual_ant_count <= 0:
			_begin_leaving()
			return
		_try_eat()

	# ─── Steer toward the nearest ant, else just keep crossing
	if is_instance_valid(_target):
		var ang = position.angle_to_point(_target.global_position)
		_heading = lerp_angle(_heading, ang, TURN_SPEED * delta)
		if GameManager.threat_level != GameManager.Threat.SCURRYING:
			GameManager.threat_level = GameManager.Threat.TENSE

func _try_eat() -> void:
	# ─── Eat everything within chomping range on this scan
	for ant in get_tree().get_nodes_in_group("ants"):
		if not is_instance_valid(ant):
			continue
		if position.distance_to(ant.global_position) <= EAT_RADIUS:
			if ant.has_method("die"):
				ant.die()                                   # drops visual count + frees the node
			GameManager.ant_count = max(0, GameManager.ant_count - 1)  # really gone for good
			GameManager.adjust_morale(-2.5)
			GameManager.threat_level = GameManager.Threat.SCURRYING
			_meals += 1
			_chomp  = 1.0
			if _meals >= MAX_MEALS:
				_begin_leaving()
				return

func _nearest_ant() -> Node2D:
	var best: Node2D = null
	var best_d: float = AWARE_RADIUS
	for ant in get_tree().get_nodes_in_group("ants"):
		if not is_instance_valid(ant):
			continue
		var d = position.distance_to(ant.global_position)
		if d < best_d:
			best_d = d
			best = ant
	return best

# =============================================================================
# LEAVE
# =============================================================================
func _begin_leaving() -> void:
	if _leaving:
		return
	_leaving = true
	_target  = null
	GameManager.threat_level = GameManager.Threat.HEIGHTENED  # danger passing

func _do_leave(delta: float) -> void:
	var ang = position.angle_to_point(Vector2(_exit_x, position.y))
	_heading = lerp_angle(_heading, ang, TURN_SPEED * 1.5 * delta)
	# ─── Off the edge → despawn and clear the slot so another can come later
	if position.x < -100.0 or position.x > WORLD_W + 100.0:
		GameManager.ant_eater_left()
		queue_free()

# =============================================================================
# MOVE
# =============================================================================
func _move(delta: float) -> void:
	rotation  = _heading
	var spd   = MOVE_SPEED * (1.3 if _leaving else 1.0)
	position += Vector2.RIGHT.rotated(_heading) * spd * delta
	# ─── Stay on-screen vertically while hunting; let it exit horizontally
	if not _leaving:
		position.y = clamp(position.y, 80.0, WORLD_H - 80.0)

# =============================================================================
# DRAWING — long-snouted critter facing +X (rotation handles direction)
# =============================================================================
func _draw() -> void:
	var body_col = Color(0.32, 0.26, 0.22)
	var dark     = Color(0.20, 0.16, 0.13)
	var light    = Color(0.45, 0.38, 0.32)
	var bob = Vector2(0, _bob)

	# ─── Bushy tail (behind, −X)
	for i in 5:
		var fx = -38.0 - i * 3.0
		var fy = -10.0 + i * 5.0
		draw_circle(Vector2(fx, fy) + bob, 8.0 - i * 0.8, dark.lerp(light, i / 5.0))

	# ─── Legs (animated little scuttle)
	var sw = sin(_walk_phase) * 4.0
	draw_line(Vector2(-14, 8) + bob, Vector2(-16, 22 + sw) + bob, dark, 3.0)
	draw_line(Vector2(-4, 8) + bob,  Vector2(-2, 22 - sw) + bob,  dark, 3.0)
	draw_line(Vector2(6, 8) + bob,   Vector2(8, 22 + sw) + bob,   dark, 3.0)

	# ─── Body (bulky, stacked circles)
	draw_circle(Vector2(-18, 0) + bob, 16.0, body_col)
	draw_circle(Vector2(-6, 2) + bob,  15.0, body_col)
	draw_circle(Vector2(6, 3) + bob,   12.0, body_col)

	# ─── Head + long snout (forward, +X)
	draw_circle(Vector2(16, 4) + bob, 8.0, body_col)
	var snout_tip = Vector2(40, 7 + _chomp * 2.0) + bob
	draw_line(Vector2(20, 5) + bob, snout_tip, body_col, 6.0)
	draw_line(Vector2(20, 5) + bob, snout_tip, dark, 2.0)
	# ─── Tongue flick on the bite
	if _chomp > 0.3:
		draw_line(snout_tip, snout_tip + Vector2(8, 0), Color(0.80, 0.20, 0.30), 1.5)
	# ─── Eye
	draw_circle(Vector2(15, 1) + bob, 1.6, Color(0.05, 0.05, 0.05))
