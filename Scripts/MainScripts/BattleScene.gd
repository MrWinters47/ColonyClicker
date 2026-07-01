extends PanelContainer

# =============================================================================
# PALETTE — warm, earthy, candlelit war-room. No cold blue/red anywhere.
# =============================================================================
const COL_BG          := Color(0.075, 0.058, 0.047, 1.0)
const COL_PANEL        := Color(0.145, 0.105, 0.078, 1.0)
const COL_PANEL_LIGHT  := Color(0.19, 0.145, 0.105, 1.0)
const COL_BORDER_GOLD  := Color(0.72, 0.55, 0.30, 0.85)
const COL_GOLD         := Color(0.87, 0.68, 0.32, 1.0)
const COL_GOLD_BRIGHT  := Color(1.0, 0.84, 0.45, 1.0)
const COL_PLAYER       := Color(0.88, 0.52, 0.20, 1.0)   # ember amber — "your side"
const COL_PLAYER_BRIGHT:= Color(1.0, 0.70, 0.32, 1.0)
const COL_ENEMY        := Color(0.70, 0.17, 0.14, 1.0)   # blood rust — enemy banners
const COL_ENEMY_BRIGHT := Color(0.92, 0.28, 0.20, 1.0)
const COL_TEXT         := Color(0.93, 0.87, 0.77, 1.0)   # parchment
const COL_DIM          := Color(0.93, 0.87, 0.77, 0.55)
const COL_VICTORY      := Color(0.78, 0.82, 0.35, 1.0)   # laurel gold-green
const COL_DEFEAT       := Color(0.55, 0.14, 0.12, 1.0)   # charred red

const FONT_PATH := "res://Assets/Fonts/Jenko-DEMO.ttf"

# =============================================================================
# TUNING — the numbers a designer would actually want to touch
# =============================================================================
const DOTS_PER_SIDE: int          = 220     # MultiMesh handles 5,000+ fine — this
											 # is a visual-density choice for a
											 # 1080px-wide phone screen, not a perf cap
const LAST_STAND_TRIGGER: float   = 0.20
const CHARGE_DURATION: float      = 1.6     # dots visually closing the gap
const VISUAL_MELEE_DURATION: float= 7.0     # fixed dramatic scrub, independent of
											 # how fast BattleSystem's math resolves

# =============================================================================
# INNER CLASS — BattleArena : the MultiMesh boid battlefield
# =============================================================================
class BattleArena extends Control:
	enum Phase { IDLE, CHARGE, SKIRMISH, AFTERMATH_WIN, AFTERMATH_LOSE }

	const N: int              = 220
	const DOT_SIZE: float      = 10.0
	const ROWS: int            = 11
	const ROW_SPACING: float   = 17.0
	const SEP_RADIUS: float    = 13.0
	const SEP_CELL: float      = 16.0
	const SEP_STRENGTH: float  = 46.0
	const WANDER_PX: float     = 26.0
	const SEEK_LERP: float     = 2.6
	const DIE_TIME: float      = 0.55

	const COL_P        := Color(0.88, 0.52, 0.20, 1.0)
	const COL_P_BRIGHT  := Color(1.0, 0.70, 0.32, 1.0)
	const COL_E        := Color(0.70, 0.17, 0.14, 1.0)
	const COL_E_BRIGHT  := Color(0.92, 0.28, 0.20, 1.0)
	const COL_GROUND    := Color(0.10, 0.075, 0.055, 0.92)
	const COL_LINE      := Color(1, 0.85, 0.6, 0.05)
	const COL_VIGNETTE  := Color(0.95, 0.55, 0.20, 0.10)
	const COL_LASTSTAND := Color(0.85, 0.20, 0.15, 1.0)

	var phase: int = Phase.IDLE
	var spawned: bool = false
	var t: float = 0.0

	var pos_p: Array = []
	var pos_e: Array = []
	var alive_p: Array = []
	var alive_e: Array = []
	var die_t_p: Array = []
	var die_t_e: Array = []
	var slot_p: Array = []
	var slot_e: Array = []
	var hue_p: Array = []
	var hue_e: Array = []

	var mm_p: MultiMeshInstance2D
	var mm_e: MultiMeshInstance2D
	var noise: FastNoiseLite

	var last_stand: bool = false
	var crit_flash: float = 0.0
	var shake_t: float = 0.0
	var win_pulse: float = 0.0

	func _ready() -> void:
		custom_minimum_size = Vector2(0, 340)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		noise = FastNoiseLite.new()
		noise.seed = randi()
		noise.frequency = 1.0
		_build_multimesh()

	func _build_multimesh() -> void:
		var quad := QuadMesh.new()
		quad.size = Vector2(DOT_SIZE, DOT_SIZE)

		var multi_p := MultiMesh.new()
		multi_p.mesh = quad
		multi_p.transform_format = MultiMesh.TRANSFORM_2D
		multi_p.use_colors = true
		multi_p.instance_count = N
		mm_p = MultiMeshInstance2D.new()
		mm_p.multimesh = multi_p
		add_child(mm_p)

		var multi_e := MultiMesh.new()
		multi_e.mesh = quad
		multi_e.transform_format = MultiMesh.TRANSFORM_2D
		multi_e.use_colors = true
		multi_e.instance_count = N
		mm_e = MultiMeshInstance2D.new()
		mm_e.multimesh = multi_e
		add_child(mm_e)

	# ─── Idle "ready for battle" formation — rows near each edge, no motion
	func _spawn_formation() -> void:
		pos_p.clear(); pos_e.clear()
		alive_p.clear(); alive_e.clear()
		die_t_p.clear(); die_t_e.clear()
		slot_p.clear(); slot_e.clear()
		hue_p.clear(); hue_e.clear()

		var mid_y: float = size.y * 0.5
		for i in N:
			var row: float = float(i % ROWS)
			var col: float = float(i / ROWS)
			var y_off: float = (row - float(ROWS - 1) * 0.5) * ROW_SPACING

			pos_p.append(Vector2(20.0 + col * 13.0, mid_y + y_off))
			alive_p.append(true)
			die_t_p.append(0.0)
			slot_p.append(y_off)
			hue_p.append(randf_range(-0.05, 0.05))

			pos_e.append(Vector2(size.x - 20.0 - col * 13.0, mid_y + y_off))
			alive_e.append(true)
			die_t_e.append(0.0)
			slot_e.append(y_off)
			hue_e.append(randf_range(-0.05, 0.05))

		spawned = true
		_push_transforms()

	func reset() -> void:
		spawned = false   # forces re-spawn into idle formation on next frame
		phase = Phase.IDLE
		last_stand = false
		crit_flash = 0.0
		shake_t = 0.0
		win_pulse = 0.0
		t = 0.0

	func begin_charge() -> void:
		phase = Phase.CHARGE
		t = 0.0

	func begin_skirmish() -> void:
		phase = Phase.SKIRMISH
		t = 0.0

	func begin_aftermath(player_won: bool) -> void:
		phase = Phase.AFTERMATH_WIN if player_won else Phase.AFTERMATH_LOSE
		t = 0.0

	func set_last_stand(active: bool) -> void:
		if active and not last_stand:
			last_stand = true

	func trigger_crit() -> void:
		crit_flash = 0.35
		shake_t = 0.35

	# ─── Map a force ratio (0..1) to alive dot count — kills the delta
	func set_force_ratio(side: String, ratio: float) -> void:
		var alive: Array = alive_p if side == "player" else alive_e
		var die_t: Array = die_t_p if side == "player" else die_t_e
		if alive.is_empty():
			return
		var target_alive: int = int(round(N * clamp(ratio, 0.0, 1.0)))
		var living_idx: Array = []
		for i in N:
			if alive[i] and die_t[i] <= 0.0:
				living_idx.append(i)
		while living_idx.size() > target_alive:
			var pick: int = living_idx.pick_random()
			living_idx.erase(pick)
			die_t[pick] = DIE_TIME

	# ─── The only place die_t counts down. Once it crosses zero the dot is
	# permanently dead (alive=false) — never revives, never resumes seeking.
	func _tick_deaths(alive: Array, die_t: Array, delta: float) -> void:
		for i in die_t.size():
			if die_t[i] > 0.0:
				die_t[i] -= delta
				if die_t[i] <= 0.0:
					die_t[i] = 0.0
					alive[i] = false

	func _process(delta: float) -> void:
		if not spawned:
			if size.x > 1.0:
				_spawn_formation()
			return

		t += delta
		if crit_flash > 0.0:
			crit_flash -= delta
		if shake_t > 0.0:
			shake_t -= delta
		if win_pulse > 0.0:
			win_pulse -= delta

		# ─── Death countdown lives in exactly one place — a dot that finishes
		# fading flips permanently to alive=false instead of reviving next frame
		_tick_deaths(alive_p, die_t_p, delta)
		_tick_deaths(alive_e, die_t_e, delta)

		match phase:
			Phase.IDLE:
				_process_idle(delta)
			Phase.CHARGE:
				_process_charge(delta)
			Phase.SKIRMISH:
				_process_skirmish(delta)
			Phase.AFTERMATH_WIN:
				_process_aftermath_win(delta)
			Phase.AFTERMATH_LOSE:
				_process_aftermath_lose(delta)

		_push_transforms()
		queue_redraw()

	func _process_idle(delta: float) -> void:
		var mid_y: float = size.y * 0.5
		for i in N:
			if alive_p[i] and die_t_p[i] <= 0.0:
				var bob: float = sin(t * 1.2 + float(i) * 0.4) * 1.5
				pos_p[i].y = mid_y + slot_p[i] + bob
			if alive_e[i] and die_t_e[i] <= 0.0:
				var bobe: float = sin(t * 1.2 + float(i) * 0.4 + 3.0) * 1.5
				pos_e[i].y = mid_y + slot_e[i] + bobe

	func _process_charge(delta: float) -> void:
		var target_x_p: float = size.x * 0.42
		var target_x_e: float = size.x * 0.58
		var mid_y: float = size.y * 0.5
		_apply_separation(pos_p, alive_p, die_t_p, delta)
		_apply_separation(pos_e, alive_e, die_t_e, delta)
		for i in N:
			_seek(pos_p, alive_p, die_t_p, i, Vector2(target_x_p, mid_y + slot_p[i]), delta, 0.0)
			_seek(pos_e, alive_e, die_t_e, i, Vector2(target_x_e, mid_y + slot_e[i]), delta, 500.0)
		if t >= CHARGE_DURATION:
			begin_skirmish()

	func _process_skirmish(delta: float) -> void:
		var mid_y: float = size.y * 0.5
		var sway: float = sin(t * 0.5) * 18.0
		var melee_x_p: float = size.x * 0.46 + sway
		var melee_x_e: float = size.x * 0.54 + sway
		_apply_separation(pos_p, alive_p, die_t_p, delta)
		_apply_separation(pos_e, alive_e, die_t_e, delta)
		for i in N:
			_seek(pos_p, alive_p, die_t_p, i, Vector2(melee_x_p, mid_y + slot_p[i] * 0.7), delta, 0.0)
			_seek(pos_e, alive_e, die_t_e, i, Vector2(melee_x_e, mid_y + slot_e[i] * 0.7), delta, 500.0)
		if last_stand:
			var entrance: Vector2 = Vector2(size.x * 0.5, size.y * 0.94)
			for i in N:
				if alive_p[i] and die_t_p[i] <= 0.0:
					pos_p[i] = pos_p[i].lerp(entrance + Vector2(slot_p[i] * 0.6, 0), 1.4 * delta)

	func _process_aftermath_win(delta: float) -> void:
		var mid_y: float = size.y * 0.5
		var melee_x_p: float = size.x * 0.48
		for i in N:
			if not alive_p[i] or die_t_p[i] > 0.0:
				continue
			var bounce: float = abs(sin(t * 3.0 + float(i) * 0.3)) * 3.0
			pos_p[i] = pos_p[i].lerp(Vector2(melee_x_p, mid_y + slot_p[i] * 0.7 - bounce), 2.0 * delta)
		for i in N:
			if alive_e[i] and die_t_e[i] <= 0.0:
				die_t_e[i] = DIE_TIME * 1.4   # rout — the rest flee off screen (fires once)

	func _process_aftermath_lose(delta: float) -> void:
		var mid_y: float = size.y * 0.5
		var entrance: Vector2 = Vector2(size.x * 0.5, size.y * 0.94)
		var melee_x_e: float = size.x * 0.5
		for i in N:
			if alive_p[i] and die_t_p[i] <= 0.0:
				pos_p[i] = pos_p[i].lerp(entrance + Vector2(slot_p[i] * 0.5, 0), 2.2 * delta)
			if alive_e[i] and die_t_e[i] <= 0.0:
				pos_e[i] = pos_e[i].lerp(Vector2(melee_x_e + slot_e[i] * 0.3, mid_y + slot_e[i] * 0.6), 1.4 * delta)

	func _seek(positions: Array, alive: Array, die_t: Array, i: int, target: Vector2, delta: float, noise_off: float) -> void:
		if die_t[i] > 0.0 or not alive[i]:
			return
		var nx: float = noise.get_noise_2d(float(i) * 3.3 + noise_off, t * 0.7)
		var ny: float = noise.get_noise_2d(float(i) * 3.3 + noise_off + 71.0, t * 0.7)
		var wobble_target: Vector2 = target + Vector2(nx, ny) * WANDER_PX
		positions[i] = positions[i].lerp(wobble_target, SEEK_LERP * delta)
		positions[i].x = clamp(positions[i].x, 4.0, size.x - 4.0)
		positions[i].y = clamp(positions[i].y, 4.0, size.y - 4.0)

	# ─── Grid-based separation — same-side neighbours only, O(n) amortised
	func _apply_separation(positions: Array, alive: Array, die_t: Array, delta: float) -> void:
		var grid: Dictionary = {}
		for i in positions.size():
			if not alive[i] or die_t[i] > 0.0:
				continue
			var cell: Vector2i = Vector2i(int(positions[i].x / SEP_CELL), int(positions[i].y / SEP_CELL))
			if not grid.has(cell):
				grid[cell] = []
			grid[cell].append(i)

		for i in positions.size():
			if not alive[i] or die_t[i] > 0.0:
				continue
			var cell: Vector2i = Vector2i(int(positions[i].x / SEP_CELL), int(positions[i].y / SEP_CELL))
			var push: Vector2 = Vector2.ZERO
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var c: Vector2i = cell + Vector2i(dx, dy)
					if not grid.has(c):
						continue
					for j in grid[c]:
						if j == i:
							continue
						var d: Vector2 = positions[i] - positions[j]
						var dist: float = d.length()
						if dist < SEP_RADIUS and dist > 0.01:
							push += d.normalized() * ((SEP_RADIUS - dist) / SEP_RADIUS)
			positions[i] += push * SEP_STRENGTH * delta

	func _push_transforms() -> void:
		for i in N:
			var a_p: float = 1.0
			if die_t_p[i] > 0.0:
				a_p = clamp(die_t_p[i] / DIE_TIME, 0.0, 1.0)
			elif not alive_p[i]:
				a_p = 0.0
			var c_p: Color = COL_P_BRIGHT if (crit_flash > 0.0) else COL_P
			c_p = c_p.lightened(hue_p[i]) if hue_p[i] > 0.0 else c_p.darkened(-hue_p[i])
			c_p.a = a_p
			mm_p.multimesh.set_instance_transform_2d(i, Transform2D(hue_p[i] * 2.0, pos_p[i]))
			mm_p.multimesh.set_instance_color(i, c_p)

			var a_e: float = 1.0
			if die_t_e[i] > 0.0:
				a_e = clamp(die_t_e[i] / DIE_TIME, 0.0, 1.0)
			elif not alive_e[i]:
				a_e = 0.0
			var c_e: Color = COL_E_BRIGHT if (crit_flash > 0.0) else COL_E
			c_e = c_e.lightened(hue_e[i]) if hue_e[i] > 0.0 else c_e.darkened(-hue_e[i])
			c_e.a = a_e
			mm_e.multimesh.set_instance_transform_2d(i, Transform2D(hue_e[i] * 2.0, pos_e[i]))
			mm_e.multimesh.set_instance_color(i, c_e)

	func _draw() -> void:
		# ─── Ground + warm corner glow ("candlelit war table")
		draw_rect(Rect2(Vector2.ZERO, size), COL_GROUND)
		draw_circle(Vector2(size.x * 0.1, size.y * 0.1), size.x * 0.35, COL_VIGNETTE)
		draw_circle(Vector2(size.x * 0.9, size.y * 0.9), size.x * 0.35, COL_VIGNETTE)
		draw_line(Vector2(size.x * 0.5, 8), Vector2(size.x * 0.5, size.y - 8), COL_LINE, 1.0)

		if crit_flash > 0.0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.85, 0.35, crit_flash * 0.28))

		if last_stand:
			var pulse: float = abs(sin(Time.get_ticks_msec() * 0.006)) * 0.55 + 0.15
			draw_rect(Rect2(Vector2.ZERO, size), Color(COL_LASTSTAND.r, COL_LASTSTAND.g, COL_LASTSTAND.b, pulse * 0.20))
			draw_rect(Rect2(Vector2.ZERO, size), Color(COL_LASTSTAND.r, COL_LASTSTAND.g, COL_LASTSTAND.b, pulse * 0.6), false, 3.0)


# =============================================================================
# NODE REFERENCES — built in _build_ui
# =============================================================================
var player_name_label:  Label
var enemy_name_label:   Label
var player_force_label: Label
var enemy_force_label:  Label
var momentum_bar:       ProgressBar
var momentum_label:     Label
var stat_grid:          GridContainer
var stat_chips: Dictionary = {}
var battle_log:         RichTextLabel
var fight_button:       Button
var close_button:       Button
var screen_tint:        ColorRect

var perks_count_label:  Label
var perk_slots: Array = []
var player_force_bar:   ProgressBar
var enemy_force_bar:    ProgressBar

var arena:               BattleArena
var phase_label:         Label
var phase_progress:      ProgressBar
var crit_counter_label:  Label
var tick_counter_label:  Label

var intro_overlay:      PanelContainer
var intro_name:         Label
var intro_lore:         Label
var intro_perk:         Label
var intro_skip:         Label

var flash_label:        Label
var _flash_tween:       Tween

var results_overlay:    PanelContainer
var results_title:      Label
var results_stats:      Label
var results_perk:       Label
var prestige_button:    Button
var continue_button:    Button

var _title_font: Font = null

# =============================================================================
# STATE
# =============================================================================
enum BPhase { IDLE, CHARGE, SKIRMISH, RESOLVE, AFTERMATH }
var _bphase: int = BPhase.IDLE

var _signals_connected: bool = false
var _shake_intensity: float  = 0.0
var _shake_timer: float      = 0.0
var _base_position: Vector2  = Vector2.ZERO
var _battle_in_progress: bool = false
var _last_result_was_defeat: bool = false

var _crit_count: int = 0
var _current_tick: int = 0
var _max_tick: int = 500

# ─── Recorded battle events — filled live, played back on a fixed dramatic clock
var _rec: Array = []
var _rec_cursor: int = 0
var _resolve_t: float = 0.0
var _charge_t: float = 0.0
var _final_result: Dictionary = {}
var _last_stand_hit: bool = false

# ─── Force bars lerp toward these every frame, independent of tick rate
var _target_p: float = 0.0
var _target_e: float = 0.0

# =============================================================================
# READY
# =============================================================================
func _ready() -> void:
	if ResourceLoader.exists(FONT_PATH):
		_title_font = load(FONT_PATH)
	_build_ui()
	_build_intro_overlay()
	_build_results_overlay()
	_connect_battle_signals()
	_connect_perk_signals()
	_show_enemy_info()
	_base_position = position

func _process(delta: float) -> void:
	if _shake_timer > 0.0:
		_shake_timer -= delta
		var s: float = _shake_intensity * (_shake_timer / 0.4)
		position = _base_position + Vector2(randf_range(-s, s), randf_range(-s, s))
		if _shake_timer <= 0.0:
			position = _base_position

	match _bphase:
		BPhase.CHARGE:
			_charge_t += delta
			if _charge_t >= CHARGE_DURATION and _rec_has_end():
				_begin_resolve()
			elif _charge_t >= CHARGE_DURATION:
				_bphase = BPhase.SKIRMISH
				if arena:
					arena.begin_skirmish()
		BPhase.SKIRMISH:
			if _rec_has_end():
				_begin_resolve()
		BPhase.RESOLVE:
			_advance_resolve(delta)

	player_force_bar.value = lerp(player_force_bar.value, _target_p, 8.0 * delta)
	enemy_force_bar.value  = lerp(enemy_force_bar.value, _target_e, 8.0 * delta)

func _rec_has_end() -> bool:
	return not _final_result.is_empty()

func _connect_battle_signals() -> void:
	if _signals_connected:
		return
	BattleSystem.battle_started.connect(_on_battle_started)
	BattleSystem.tick_resolved.connect(_on_tick_resolved)
	BattleSystem.narrative_line.connect(_on_narrative_line)
	BattleSystem.battle_ended.connect(_on_battle_ended)
	BattleSystem.crit_landed.connect(_on_crit)
	BattleSystem.queen_killed.connect(_on_queen_killed)
	_signals_connected = true

func _connect_perk_signals() -> void:
	if EventBus.has_signal("perks_changed"):
		EventBus.perks_changed.connect(_refresh_perks)
	if EventBus.has_signal("perk_activated"):
		EventBus.perk_activated.connect(func(_id): _refresh_perks())
	_refresh_perks()

func _apply_font(ctrl: Control) -> void:
	if _title_font:
		ctrl.add_theme_font_override("font", _title_font)

# =============================================================================
# UI BUILDER
# =============================================================================
func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_BG
	add_theme_stylebox_override("panel", sb)

	screen_tint = ColorRect.new()
	screen_tint.color = Color(0, 0, 0, 0)
	screen_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(screen_tint)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	root.add_child(_build_combatants_banner())
	root.add_child(_build_phase_indicator())
	root.add_child(_build_momentum_section())
	root.add_child(_build_arena_section())
	root.add_child(_build_stat_grid())
	root.add_child(_build_perks_section())
	root.add_child(_build_bottom_bar())

	flash_label = Label.new()
	flash_label.text = ""
	flash_label.add_theme_font_size_override("font_size", 72)
	_apply_font(flash_label)
	flash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flash_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	flash_label.set_anchors_preset(Control.PRESET_CENTER)
	flash_label.modulate.a = 0.0
	flash_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_label)

func _make_panel() -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PANEL
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	sb.border_color = COL_BORDER_GOLD
	sb.set_content_margin_all(12)
	pc.add_theme_stylebox_override("panel", sb)
	return pc

# ─── Combatants — names + big force counts either side of a gold VS emblem
func _build_combatants_banner() -> PanelContainer:
	var panel := _make_panel()
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(left)

	player_name_label = Label.new()
	player_name_label.add_theme_font_size_override("font_size", 22)
	_apply_font(player_name_label)
	player_name_label.add_theme_color_override("font_color", COL_PLAYER)
	player_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(player_name_label)

	player_force_label = Label.new()
	player_force_label.add_theme_font_size_override("font_size", 36)
	_apply_font(player_force_label)
	player_force_label.add_theme_color_override("font_color", COL_TEXT)
	player_force_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(player_force_label)

	var vs := Label.new()
	vs.text = "VS"
	vs.add_theme_font_size_override("font_size", 28)
	_apply_font(vs)
	vs.add_theme_color_override("font_color", COL_GOLD)
	vs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(vs)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(right)

	enemy_name_label = Label.new()
	enemy_name_label.add_theme_font_size_override("font_size", 22)
	_apply_font(enemy_name_label)
	enemy_name_label.add_theme_color_override("font_color", COL_ENEMY_BRIGHT)
	enemy_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(enemy_name_label)

	enemy_force_label = Label.new()
	enemy_force_label.add_theme_font_size_override("font_size", 36)
	_apply_font(enemy_force_label)
	enemy_force_label.add_theme_color_override("font_color", COL_TEXT)
	enemy_force_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(enemy_force_label)

	return panel

func _build_phase_indicator() -> PanelContainer:
	var panel := _make_panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)

	var top := HBoxContainer.new()
	box.add_child(top)

	phase_label = Label.new()
	phase_label.text = "AWAITING ORDERS"
	phase_label.add_theme_font_size_override("font_size", 17)
	_apply_font(phase_label)
	phase_label.add_theme_color_override("font_color", COL_DIM)
	phase_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(phase_label)

	crit_counter_label = Label.new()
	crit_counter_label.text = "CRITS: 0"
	crit_counter_label.add_theme_font_size_override("font_size", 13)
	crit_counter_label.add_theme_color_override("font_color", COL_GOLD)
	top.add_child(crit_counter_label)

	var sep := Control.new()
	sep.custom_minimum_size.x = 12
	top.add_child(sep)

	tick_counter_label = Label.new()
	tick_counter_label.text = "TICK 0 / 500"
	tick_counter_label.add_theme_font_size_override("font_size", 13)
	tick_counter_label.add_theme_color_override("font_color", COL_DIM)
	top.add_child(tick_counter_label)

	phase_progress = ProgressBar.new()
	phase_progress.show_percentage = false
	phase_progress.custom_minimum_size.y = 6
	phase_progress.max_value = 100
	phase_progress.value = 0
	var bg := StyleBoxFlat.new()
	bg.bg_color = COL_BG
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = COL_GOLD
	fg.set_corner_radius_all(3)
	phase_progress.add_theme_stylebox_override("background", bg)
	phase_progress.add_theme_stylebox_override("fill", fg)
	box.add_child(phase_progress)

	return panel

func _build_momentum_section() -> PanelContainer:
	var panel := _make_panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)

	momentum_label = Label.new()
	momentum_label.text = "MOMENTUM"
	momentum_label.add_theme_font_size_override("font_size", 13)
	momentum_label.add_theme_color_override("font_color", COL_DIM)
	momentum_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(momentum_label)

	momentum_bar = ProgressBar.new()
	momentum_bar.show_percentage = false
	momentum_bar.custom_minimum_size.y = 22
	momentum_bar.max_value = 100
	momentum_bar.value = 50
	var bg := StyleBoxFlat.new()
	bg.bg_color = COL_ENEMY.darkened(0.35)
	bg.set_corner_radius_all(7)
	var fg := StyleBoxFlat.new()
	fg.bg_color = COL_PLAYER
	fg.set_corner_radius_all(7)
	momentum_bar.add_theme_stylebox_override("background", bg)
	momentum_bar.add_theme_stylebox_override("fill", fg)
	box.add_child(momentum_bar)

	return panel

func _build_stat_grid() -> PanelContainer:
	var panel := _make_panel()
	stat_grid = GridContainer.new()
	stat_grid.columns = 4
	stat_grid.add_theme_constant_override("h_separation", 8)
	stat_grid.add_theme_constant_override("v_separation", 6)
	panel.add_child(stat_grid)

	var stats = ["ATK", "DEF", "SPD", "MORALE"]
	for s in stats:
		stat_grid.add_child(_make_stat_header(s))
	for s in stats:
		var chip = _make_stat_chip(COL_PLAYER)
		stat_chips["player_" + s.to_lower()] = chip
		stat_grid.add_child(chip)
	for s in stats:
		var chip = _make_stat_chip(COL_ENEMY_BRIGHT)
		stat_chips["enemy_" + s.to_lower()] = chip
		stat_grid.add_child(chip)

	return panel

func _make_stat_header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", COL_DIM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _make_stat_chip(color: Color) -> Label:
	var l := Label.new()
	l.text = "—"
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _build_perks_section() -> PanelContainer:
	perk_slots.clear()
	var panel := _make_panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)

	var title := Label.new()
	title.text = "BATTLE PERKS"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", COL_DIM)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	perks_count_label = Label.new()
	perks_count_label.text = "0 / 3"
	perks_count_label.add_theme_font_size_override("font_size", 13)
	perks_count_label.add_theme_color_override("font_color", COL_GOLD)
	header.add_child(perks_count_label)

	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 8)
	for i in 3:
		slots.add_child(_make_perk_slot())
	box.add_child(slots)

	return panel

func _make_perk_slot() -> PanelContainer:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.custom_minimum_size.y = 38
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_BG.lightened(0.04)
	sb.set_corner_radius_all(7)
	sb.set_border_width_all(1)
	sb.border_color = COL_DIM
	sb.set_content_margin_all(6)
	pc.add_theme_stylebox_override("panel", sb)

	var l := Label.new()
	l.text = "+"
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", COL_DIM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pc.add_child(l)
	perk_slots.append(l)
	return pc

# ─── The Arena — MultiMesh dot battlefield is the centrepiece
func _build_arena_section() -> PanelContainer:
	var panel := _make_panel()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(box)

	box.add_child(_build_force_row("YOUR FORCE", COL_PLAYER, true))

	arena = BattleArena.new()
	arena.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena.custom_minimum_size = Vector2(0, 340)
	arena.clip_contents = true
	box.add_child(arena)

	box.add_child(_build_force_row("ENEMY FORCE", COL_ENEMY_BRIGHT, false))

	battle_log = RichTextLabel.new()
	battle_log.bbcode_enabled = true
	battle_log.scroll_following = true
	battle_log.custom_minimum_size.y = 84
	battle_log.add_theme_font_size_override("normal_font_size", 13)
	var log_sb := StyleBoxFlat.new()
	log_sb.bg_color = COL_BG.lightened(0.02)
	log_sb.set_corner_radius_all(6)
	log_sb.set_content_margin_all(8)
	battle_log.add_theme_stylebox_override("normal", log_sb)
	box.add_child(battle_log)

	return panel

func _build_force_row(title: String, color: Color, is_player: bool) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)

	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", COL_DIM)
	col.add_child(lbl)

	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 18
	bar.max_value = 100
	bar.value = 100
	var bg := StyleBoxFlat.new()
	bg.bg_color = COL_PANEL_LIGHT
	bg.set_corner_radius_all(5)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	col.add_child(bar)

	if is_player:
		player_force_bar = bar
	else:
		enemy_force_bar = bar
	return col

func _build_bottom_bar() -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)

	fight_button = Button.new()
	fight_button.text = "⚔  FIGHT"
	fight_button.add_theme_font_size_override("font_size", 28)
	_apply_font(fight_button)
	fight_button.custom_minimum_size.y = 72
	fight_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = COL_PLAYER.darkened(0.25)
	fsb.set_corner_radius_all(10)
	fsb.set_border_width_all(2)
	fsb.border_color = COL_GOLD
	var fsb_hover := fsb.duplicate()
	fsb_hover.bg_color = COL_PLAYER
	fight_button.add_theme_stylebox_override("normal", fsb)
	fight_button.add_theme_stylebox_override("hover", fsb_hover)
	fight_button.add_theme_stylebox_override("pressed", fsb_hover)
	fight_button.pressed.connect(_on_fight_pressed)
	box.add_child(fight_button)

	close_button = Button.new()
	close_button.text = "✕"
	close_button.add_theme_font_size_override("font_size", 34)
	close_button.custom_minimum_size = Vector2(64, 64)
	var csb := StyleBoxFlat.new()
	csb.bg_color = COL_PANEL_LIGHT
	csb.set_corner_radius_all(10)
	csb.set_border_width_all(1)
	csb.border_color = COL_DIM
	close_button.add_theme_stylebox_override("normal", csb)
	close_button.pressed.connect(_on_close_pressed)
	box.add_child(close_button)

	return box

# =============================================================================
# INTRO OVERLAY — shows enemy queen lore, tap to start
# =============================================================================
func _build_intro_overlay() -> void:
	intro_overlay = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(COL_BG.r, COL_BG.g, COL_BG.b, 0.95)
	intro_overlay.add_theme_stylebox_override("panel", sb)
	intro_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	intro_overlay.visible = false
	intro_overlay.gui_input.connect(_on_intro_tapped)
	intro_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(intro_overlay)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 80)
	margin.add_theme_constant_override("margin_bottom", 80)
	intro_overlay.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(box)

	var challenger := Label.new()
	challenger.text = "A CHALLENGER APPROACHES"
	challenger.add_theme_font_size_override("font_size", 18)
	challenger.add_theme_color_override("font_color", COL_GOLD)
	challenger.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(challenger)

	intro_name = Label.new()
	intro_name.add_theme_font_size_override("font_size", 46)
	_apply_font(intro_name)
	intro_name.add_theme_color_override("font_color", COL_ENEMY_BRIGHT)
	intro_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(intro_name)

	intro_lore = Label.new()
	intro_lore.add_theme_font_size_override("font_size", 20)
	intro_lore.add_theme_color_override("font_color", COL_TEXT)
	intro_lore.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(intro_lore)

	intro_perk = Label.new()
	intro_perk.add_theme_font_size_override("font_size", 17)
	intro_perk.add_theme_color_override("font_color", COL_GOLD)
	intro_perk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_perk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(intro_perk)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 36
	box.add_child(spacer)

	intro_skip = Label.new()
	intro_skip.text = "tap to continue"
	intro_skip.add_theme_font_size_override("font_size", 15)
	intro_skip.add_theme_color_override("font_color", COL_DIM)
	intro_skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(intro_skip)

func _show_intro() -> void:
	var queen = EnemyColonies.get_current()
	intro_name.text = queen.name.to_upper()
	intro_lore.text = queen.get("lore", "")
	intro_perk.text = "Reward: " + queen.get("perk", "")
	intro_overlay.modulate.a = 0.0
	intro_overlay.show()
	var tween = create_tween()
	tween.tween_property(intro_overlay, "modulate:a", 1.0, 0.3)

func _on_intro_tapped(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_intro_and_fight()

func _close_intro_and_fight() -> void:
	var tween = create_tween()
	tween.tween_property(intro_overlay, "modulate:a", 0.0, 0.2)
	await tween.finished
	intro_overlay.hide()
	_start_battle_for_real()

# =============================================================================
# RESULTS OVERLAY
# =============================================================================
func _build_results_overlay() -> void:
	results_overlay = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(COL_BG.r, COL_BG.g, COL_BG.b, 0.97)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(26)
	results_overlay.add_theme_stylebox_override("panel", sb)
	results_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	results_overlay.visible = false
	add_child(results_overlay)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	results_overlay.add_child(box)

	results_title = Label.new()
	results_title.add_theme_font_size_override("font_size", 48)
	_apply_font(results_title)
	results_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(results_title)

	results_stats = Label.new()
	results_stats.add_theme_font_size_override("font_size", 20)
	results_stats.add_theme_color_override("font_color", COL_TEXT)
	results_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(results_stats)

	results_perk = Label.new()
	results_perk.add_theme_font_size_override("font_size", 20)
	results_perk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	results_perk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	results_perk.add_theme_color_override("font_color", COL_GOLD)
	box.add_child(results_perk)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	prestige_button = Button.new()
	prestige_button.add_theme_font_size_override("font_size", 24)
	_apply_font(prestige_button)
	prestige_button.custom_minimum_size.y = 76
	prestige_button.pressed.connect(_on_prestige_pressed)
	box.add_child(prestige_button)

	continue_button = Button.new()
	continue_button.text = "CONTINUE"
	continue_button.add_theme_font_size_override("font_size", 20)
	continue_button.custom_minimum_size.y = 60
	continue_button.pressed.connect(_on_continue_pressed)
	box.add_child(continue_button)

# =============================================================================
# ENEMY INFO REFRESH (pre-fight)
# =============================================================================
func _show_enemy_info() -> void:
	var enemy = EnemyColonies.get_current()
	var c = GameManager.active_colony
	player_name_label.text = c.colony_name if c else "Your Colony"
	enemy_name_label.text = enemy.name

	var p_force = int(max(GameManager.ant_count, 5) * BattleSystem.ANT_FORCE_MULT)
	var e_force = enemy.workers + enemy.soldiers
	player_force_label.text = _fmt(p_force)
	enemy_force_label.text  = _fmt(e_force)

	if player_force_bar:
		player_force_bar.max_value = max(p_force, 1)
		player_force_bar.value     = p_force
	if enemy_force_bar:
		enemy_force_bar.max_value  = max(e_force, 1)
		enemy_force_bar.value      = e_force
	_target_p = p_force
	_target_e = e_force

	if c:
		stat_chips["player_atk"].text    = str(int(c.base_attack))
		stat_chips["player_def"].text    = str(int(c.base_defense))
		stat_chips["player_spd"].text    = "%.1f" % c.base_speed
		stat_chips["player_morale"].text = "100"
	stat_chips["enemy_atk"].text    = str(int(enemy.worker_dmg))
	stat_chips["enemy_def"].text    = str(int(enemy.armor))
	stat_chips["enemy_spd"].text    = "%.1f" % enemy.speed
	stat_chips["enemy_morale"].text = "100"

	var total = p_force + e_force
	momentum_bar.value = (float(p_force) / total) * 100.0 if total > 0 else 50.0

	phase_label.text = "AWAITING ORDERS"
	phase_label.add_theme_color_override("font_color", COL_DIM)
	crit_counter_label.text = "CRITS: 0"
	tick_counter_label.text = "TICK 0 / 500"
	phase_progress.value = 0
	_bphase = BPhase.IDLE
	_last_stand_hit = false
	if arena:
		arena.reset()

# =============================================================================
# FIGHT FLOW
# =============================================================================
func _on_fight_pressed() -> void:
	if _battle_in_progress:
		return
	_show_intro()

func _start_battle_for_real() -> void:
	_battle_in_progress = true
	_crit_count = 0
	_current_tick = 0
	_rec.clear()
	_rec_cursor = 0
	_resolve_t = 0.0
	_charge_t = 0.0
	_final_result = {}
	_last_stand_hit = false
	crit_counter_label.text = "CRITS: 0"

	fight_button.disabled = true
	results_overlay.hide()
	screen_tint.color = Color(0, 0, 0, 0)
	battle_log.text = ""
	_log_styled("⚔ THE BATTLE BEGINS ⚔", COL_GOLD, true)
	var enemy = EnemyColonies.get_current()
	_log_line("Your colony charges the %s colony!" % enemy.name)

	if arena:
		arena.reset()
	# arena needs one frame to re-spawn its idle formation before charging
	await get_tree().process_frame
	if arena:
		arena.begin_charge()
	_bphase = BPhase.CHARGE

	BattleSystem.start_battle(enemy)

# =============================================================================
# BATTLE SIGNAL HANDLERS — these only RECORD. Nothing here touches the UI
# directly, so the visual battle can run on its own fixed dramatic clock no
# matter how fast BattleSystem's math resolves underneath it.
# =============================================================================
func _on_battle_started(player: Dictionary, enemy: Dictionary) -> void:
	pass  # opening state is already shown by _start_battle_for_real / _show_enemy_info

func _on_tick_resolved(snapshot: Dictionary) -> void:
	_rec.append({"type": "tick", "data": snapshot})

func _on_narrative_line(text: String) -> void:
	_rec.append({"type": "line", "text": text})

func _on_crit(side: String, text: String) -> void:
	_rec.append({"type": "crit", "side": side, "text": text})

func _on_queen_killed(side: String) -> void:
	_rec.append({"type": "queen", "side": side})

func _on_battle_ended(result: Dictionary) -> void:
	_final_result = result

# =============================================================================
# RESOLVE PLAYBACK — scrubs through _rec on a fixed dramatic clock
# =============================================================================
func _begin_resolve() -> void:
	_bphase = BPhase.RESOLVE
	_resolve_t = 0.0
	_rec_cursor = 0

func _advance_resolve(delta: float) -> void:
	_resolve_t += delta
	var progress: float = clamp(_resolve_t / VISUAL_MELEE_DURATION, 0.0, 1.0)
	var target_cursor: int = int(progress * float(_rec.size()))
	target_cursor = min(target_cursor, _rec.size())
	while _rec_cursor < target_cursor:
		_apply_rec_event(_rec[_rec_cursor])
		_rec_cursor += 1
	if progress >= 1.0:
		_finish_battle()

func _apply_rec_event(ev: Dictionary) -> void:
	match ev.type:
		"tick":
			_apply_tick_snapshot(ev.data)
		"line":
			_log_line(ev.text)
		"crit":
			_crit_count += 1
			crit_counter_label.text = "CRITS: %d" % _crit_count
			if arena:
				arena.trigger_crit()
			_shake(7.0, 0.35)
			_flash("CRIT!", COL_GOLD)
			_log_styled(ev.text, COL_GOLD, false)
		"queen":
			_shake(13.0, 0.55)
			if ev.side == "enemy":
				_flash("QUEEN DOWN!", COL_VICTORY)
			else:
				_flash("YOUR QUEEN!", COL_DEFEAT)

func _apply_tick_snapshot(snapshot: Dictionary) -> void:
	var p: int = snapshot.player.workers + snapshot.player.soldiers
	var e: int = snapshot.enemy.workers + snapshot.enemy.soldiers
	player_force_label.text = _fmt(p)
	enemy_force_label.text  = _fmt(e)
	_target_p = p
	_target_e = e

	var p_max: int = int(snapshot.player.get("max_force", p))
	var e_max: int = int(snapshot.enemy.get("max_force", e))
	var p_ratio: float = float(p) / max(p_max, 1)
	var e_ratio: float = float(e) / max(e_max, 1)
	if arena:
		arena.set_force_ratio("player", p_ratio)
		arena.set_force_ratio("enemy", e_ratio)
		if p_ratio < LAST_STAND_TRIGGER and p > 0:
			_last_stand_hit = true
			arena.set_last_stand(true)

	_current_tick = int(snapshot.tick)
	_max_tick = int(snapshot.max_tick)
	_update_phase_indicator()

	var total: int = p + e
	var target_momentum: float = (float(p) / total) * 100.0 if total > 0 else 50.0
	momentum_bar.value = lerp(momentum_bar.value, target_momentum, 0.4)

	stat_chips["player_morale"].text = str(int(snapshot.player.morale))
	stat_chips["enemy_morale"].text  = str(int(snapshot.enemy.morale))

	var lead: float = (float(p) / total) - 0.5 if total > 0 else 0.0
	var tint_a: float = clamp(abs(lead) * 0.35, 0.0, 0.26)
	var tint_c: Color = COL_VICTORY if lead > 0 else COL_DEFEAT
	screen_tint.color = Color(tint_c.r, tint_c.g, tint_c.b, tint_a)

func _update_phase_indicator() -> void:
	var pct: float = float(_current_tick) / max(_max_tick, 1)
	var phase_text: String = "THE CHARGE"
	var phase_col: Color = COL_TEXT

	if _last_stand_hit:
		phase_text = "★ LAST STAND ★"
		phase_col = COL_DEFEAT
	elif pct < 0.30:
		phase_text = "THE CHARGE"
		phase_col = COL_TEXT
	elif pct < 0.65:
		phase_text = "LOCKED IN COMBAT"
		phase_col = COL_GOLD
	else:
		phase_text = "THE FINAL PUSH"
		phase_col = COL_ENEMY_BRIGHT

	phase_label.text = phase_text
	phase_label.add_theme_color_override("font_color", phase_col)
	phase_progress.value = pct * 100
	tick_counter_label.text = "TICK %d / %d" % [_current_tick, _max_tick]

func _finish_battle() -> void:
	_bphase = BPhase.AFTERMATH
	var won: bool = _final_result.get("winner", "enemy") == "player"
	if arena:
		arena.begin_aftermath(won)
	fight_button.disabled = false
	_battle_in_progress = false

	if won:
		_flash("VICTORY", COL_VICTORY)
		_shake(18.0, 0.7)
	else:
		_flash("DEFEAT", COL_DEFEAT)
		_shake(18.0, 0.7)

	await get_tree().create_timer(1.0).timeout
	if won:
		_show_victory(_final_result)
	else:
		_show_defeat(_final_result)

# =============================================================================
# VICTORY / DEFEAT / PRESTIGE
# =============================================================================
func _show_victory(result: Dictionary) -> void:
	_last_result_was_defeat = false
	var queen = EnemyColonies.get_current()

	# ─── Queen-perk granting is data-gated: EnemyColonies queens carry a
	# flavour "perk" string but no structured perk_id, so PerkManager has
	# nothing to look up yet. Calls preserved (forward-compatible if/when
	# a perk_id field gets added), falls back to the flavour text so the
	# screen never shows a blank reward.
	if PerkManager.has_method("grant_artifact"):
		PerkManager.grant_artifact(queen.get("perk_id", ""))

	results_title.text = "★ VICTORY ★"
	results_title.add_theme_color_override("font_color", COL_VICTORY)
	results_stats.text = "Won by %s\nYour losses: %d%%   Enemy losses: %d%%" % [
		result.method, int(result.player_loss * 100), int(result.enemy_loss * 100)
	]

	var perk = null
	if PerkManager.has_method("get_def"):
		perk = PerkManager.get_def(queen.get("perk_id", ""))
	if perk:
		results_perk.text = "✦ NEW PERK UNLOCKED ✦\n%s — %s" % [perk.display_name, perk.description]
	else:
		results_perk.text = "✦ QUEEN PERK ✦\n%s" % queen.get("perk", "")

	prestige_button.text = "👑 BECOME THE %s QUEEN" % queen.name.to_upper()
	prestige_button.show()
	results_overlay.show()

func _show_defeat(result: Dictionary) -> void:
	_last_result_was_defeat = true
	results_title.text = "DEFEAT"
	results_title.add_theme_color_override("font_color", COL_DEFEAT)
	results_stats.text = "Your losses: %d%%   Enemy losses: %d%%\nGrow the colony and try again." % [
		int(result.player_loss * 100), int(result.enemy_loss * 100)
	]
	results_perk.text = ""
	prestige_button.hide()
	results_overlay.show()

func _on_prestige_pressed() -> void:
	var queen = EnemyColonies.get_current()
	# ─── Known gap, unchanged this pass: EnemyColonies.build_colony_stats()
	# does not exist yet. Guarded so pressing this button degrades to a
	# no-op instead of a hard crash until that's wired.
	if EnemyColonies.has_method("build_colony_stats"):
		var new_stats = EnemyColonies.build_colony_stats(queen)
		GameManager.prestige(new_stats)
		EnemyColonies.advance()
		results_overlay.hide()
		screen_tint.color = Color(0, 0, 0, 0)
		battle_log.text = ""
		_log_styled("A new reign begins — %s." % queen.colony_name, COL_GOLD, true)
		_show_enemy_info()
	else:
		push_warning("BattleScene: EnemyColonies.build_colony_stats() missing — prestige skipped")

func _on_continue_pressed() -> void:
	results_overlay.hide()
	screen_tint.color = Color(0, 0, 0, 0)
	if _last_result_was_defeat:
		hide()

func _on_close_pressed() -> void:
	if _battle_in_progress:
		BattleSystem.abort()
		_battle_in_progress = false
		fight_button.disabled = false
	_bphase = BPhase.IDLE
	screen_tint.color = Color(0, 0, 0, 0)
	results_overlay.hide()
	hide()

# =============================================================================
# EFFECTS
# =============================================================================
func _shake(intensity: float, duration: float) -> void:
	_shake_intensity = intensity
	_shake_timer = duration

func _flash(text: String, color: Color) -> void:
	if _flash_tween:
		_flash_tween.kill()
	flash_label.text = text
	flash_label.add_theme_color_override("font_color", color)
	flash_label.modulate.a = 0.0
	flash_label.scale = Vector2(0.7, 0.7)
	_flash_tween = create_tween().set_parallel(true)
	_flash_tween.tween_property(flash_label, "modulate:a", 1.0, 0.15)
	_flash_tween.tween_property(flash_label, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flash_tween.chain().tween_property(flash_label, "modulate:a", 0.0, 0.4).set_delay(0.5)

# =============================================================================
# PERK ROW REFRESH (defensive — tolerates whatever PerkManager exposes)
# =============================================================================
func _refresh_perks() -> void:
	var active: Array = []
	if PerkManager.has_method("get_active_list"):
		active = PerkManager.get_active_list()
	perks_count_label.text = "%d / 3" % active.size()
	for i in perk_slots.size():
		var lbl: Label = perk_slots[i]
		if i < active.size():
			lbl.text = _perk_name(active[i])
			lbl.add_theme_color_override("font_color", COL_GOLD)
		else:
			lbl.text = "+"
			lbl.add_theme_color_override("font_color", COL_DIM)

func _perk_name(p) -> String:
	if p is PerkDef:
		return p.display_name
	if typeof(p) == TYPE_STRING:
		return p
	return "?"

# =============================================================================
# LOG HELPERS
# =============================================================================
func _log_line(text: String) -> void:
	battle_log.append_text("\n" + text)

func _log_styled(text: String, color: Color, big: bool) -> void:
	var hex = color.to_html(false)
	if big:
		battle_log.append_text("\n[center][b][color=#%s]%s[/color][/b][/center]" % [hex, text])
	else:
		battle_log.append_text("\n[color=#%s]%s[/color]" % [hex, text])

func _fmt(n: int) -> String:
	var s = str(n)
	var result = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		result = s[i] + result
		count += 1
		if count % 3 == 0 and i > 0:
			result = "," + result
	return result
