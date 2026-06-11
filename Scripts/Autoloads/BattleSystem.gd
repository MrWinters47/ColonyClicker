extends Node

# =============================================================================
# SIGNALS — UI and visual layers connect to these
# =============================================================================
signal battle_started(player: Dictionary, enemy: Dictionary)
signal tick_resolved(snapshot: Dictionary)
signal crit_landed(side: String, text: String)
signal narrative_line(text: String)
signal queen_killed(side: String)
signal morale_break(side: String)
signal battle_ended(result: Dictionary)

# =============================================================================
# BALANCE CONSTANTS — tweak here, nowhere else
# =============================================================================
const DAMAGE_VARIANCE   = 0.06
const CRIT_CHANCE       = 0.08
const ROUT_THRESHOLD    = 12.0
const ROUT_CHANCE       = 0.08
const QUEEN_KILL_CHANCE = 0.020
const MAX_TICKS         = 500
const ANT_FORCE_MULT    = 500.0   # ⚠️ comment used to say 80 — this is the balance bug

# =============================================================================
# TIMING — drives the real-time feel
# =============================================================================
const BASE_TICK_INTERVAL: float = 0.12  # 500 ticks × 0.12s = 60s ceiling at 1x
var   speed_multiplier:   float = 1.0   # 1x / 2x / 4x — UI sets this
var   tick_interval:      float = BASE_TICK_INTERVAL
var   _tick_timer:        float = 0.0

# =============================================================================
# STATE
# =============================================================================
var is_active: bool = false
var is_paused: bool = false

var player_state: Dictionary = {}
var enemy_state:  Dictionary = {}
var current_tick: int        = 0
var a_luck:       float      = 1.0
var b_luck:       float      = 1.0
var routed:       String     = ""
var _battle_log:  Array      = []

# =============================================================================
# PUBLIC API
# =============================================================================
func start_battle(enemy: Dictionary) -> void:
	# ─── Reset state and begin a real-time battle
	if is_active:
		push_warning("BattleSystem: battle already in progress — overwriting")
	
	player_state = _build_player_dict()
	enemy_state  = enemy.duplicate()
	
	player_state["max_force"]   = player_state.workers + player_state.soldiers
	enemy_state["max_force"]    = enemy_state.workers + enemy_state.soldiers
	player_state["morale"]      = 100.0
	enemy_state["morale"]       = 100.0
	player_state["queen_alive"] = GameManager.queen_alive
	enemy_state["queen_alive"]  = true
	
	a_luck       = randf_range(0.95, 1.05)
	b_luck       = randf_range(0.95, 1.05)
	current_tick = 0
	routed       = ""
	_battle_log.clear()
	_tick_timer  = 0.0
	is_active    = true
	is_paused    = false
	
	battle_started.emit(player_state.duplicate(), enemy_state.duplicate())

func set_speed(mult: float) -> void:
	# ─── 1x / 2x / 4x — can change mid-battle
	speed_multiplier = max(0.25, mult)
	tick_interval    = BASE_TICK_INTERVAL / speed_multiplier

func pause() -> void:
	is_paused = true

func resume() -> void:
	is_paused = false

func abort() -> void:
	# ─── Cancel the battle without emitting battle_ended
	is_active = false
	is_paused = false

# =============================================================================
# PROCESS — drives ticks on a timer
# =============================================================================
func _process(delta: float) -> void:
	if not is_active or is_paused:
		return
	
	_tick_timer += delta
	if _tick_timer >= tick_interval:
		_tick_timer = 0.0
		_advance_tick()

func _advance_tick() -> void:
	# ─── End conditions
	if _total(player_state) <= 0 or _total(enemy_state) <= 0:
		_finalize()
		return
	if current_tick >= MAX_TICKS:
		_finalize()
		return
	
	var progress  = float(current_tick) / MAX_TICKS
	var intensity = 0.4 + progress * 1.0
	var a_attacks = randf() < (player_state.speed / (player_state.speed + enemy_state.speed))
	
	if a_attacks:
		var result = _tick(player_state, enemy_state, a_luck, intensity)
		if result.crit and current_tick % 18 == 0:
			var text = "CRIT! Your colony lands a devastating blow!"
			_emit_log(text, "player")
			crit_landed.emit("player", text)
	else:
		var result = _tick(enemy_state, player_state, b_luck, intensity)
		if result.crit and current_tick % 18 == 0:
			var text = "CRIT! %s strikes hard!" % enemy_state.name
			_emit_log(text, "enemy")
			crit_landed.emit("enemy", text)
	
	# ─── Narrative beats
	if current_tick == 30:
		_emit_log("Both colonies clash — the ground shakes.", "")
	if current_tick == 60:
		_emit_log(_midpoint_line(player_state, enemy_state), "")
	if current_tick == 100:
		_emit_log(_late_line(player_state, enemy_state), "")
	
	# ─── Queen kill checks
	if progress > 0.66:
		if enemy_state.queen_alive and _pct(enemy_state) < 0.25 and randf() < QUEEN_KILL_CHANCE:
			enemy_state.queen_alive = false
			enemy_state.morale      = max(0, enemy_state.morale - 30)
			_emit_log("Their queen has been killed! Enemy morale collapses!", "")
			queen_killed.emit("enemy")
		if player_state.queen_alive and _pct(player_state) < 0.25 and randf() < QUEEN_KILL_CHANCE:
			player_state.queen_alive = false
			player_state.morale      = max(0, player_state.morale - 30)
			_emit_log("Your queen has fallen! Hold the line!", "")
			queen_killed.emit("player")
	
	# ─── Rout checks
	if enemy_state.morale < ROUT_THRESHOLD and randf() < ROUT_CHANCE * (1.0 - enemy_state.aggression):
		_emit_log("%s breaks and flees!" % enemy_state.name, "")
		routed = "enemy"
		morale_break.emit("enemy")
		_finalize()
		return
	if player_state.morale < ROUT_THRESHOLD and randf() < ROUT_CHANCE * (1.0 - player_state.aggression):
		_emit_log("Your colony breaks under pressure!", "")
		routed = "player"
		morale_break.emit("player")
		_finalize()
		return
	
	current_tick += 1
	
	# ─── Snapshot for the UI — health bars, dots, etc.
	tick_resolved.emit({
		"tick":       current_tick,
		"max_tick":   MAX_TICKS,
		"player":     player_state.duplicate(),
		"enemy":      enemy_state.duplicate(),
		"player_pct": _pct(player_state),
		"enemy_pct":  _pct(enemy_state),
	})

func _emit_log(text: String, side: String) -> void:
	_battle_log.append({
		"text": text,
		"pf":   _total(player_state),
		"ef":   _total(enemy_state),
		"side": side,
	})
	narrative_line.emit(text)

func _finalize() -> void:
	# ─── Wrap up and emit the final result
	var winner := ""
	var method := ""
	if routed == "enemy":
		winner = "player"; method = "rout"
	elif routed == "player":
		winner = "enemy"; method = "rout"
	elif _total(player_state) > _total(enemy_state):
		winner = "player"
		method = "annihilation" if _total(enemy_state) == 0 else "field control"
	else:
		winner = "enemy"
		method = "annihilation" if _total(player_state) == 0 else "field control"
	
	_emit_log("--- BATTLE OVER ---", "")
	if winner == "player":
		_emit_log("VICTORY! %s colony defeated!" % enemy_state.name, "player")
	else:
		_emit_log("DEFEAT. Regroup and try again.", "enemy")
	
	is_active = false
	
	battle_ended.emit({
		"winner":      winner,
		"method":      method,
		"player_loss": 1.0 - _pct(player_state),
		"enemy_loss":  1.0 - _pct(enemy_state),
		"log":         _battle_log.duplicate(),
		"max_player":  player_state.get("max_force", 0),
		"max_enemy":   enemy_state.get("max_force", 0),
	})


# =============================================================================
# CORE COMBAT MATH — unchanged from original
# =============================================================================
func _build_player_dict() -> Dictionary:
	var c = GameManager.active_colony
	if not c:
		return {
			"name": "Your Colony", "workers": 500, "soldiers": 0,
			"worker_dmg": 10, "soldier_dmg": 20,
			"worker_hp": 40, "soldier_hp": 80,
			"speed": 1.0, "aggression": 0.7, "cohesion": 0.5,
			"armor": 5, "venom": 2, "queen_buff": 1.1, "panic_resist": 0.3
		}
	return {
		"name":         c.colony_name,
		"workers":      int(max(GameManager.ant_count, 5) * ANT_FORCE_MULT),
		"soldiers":     0,
		"worker_dmg":  c.base_attack * PerkManager.get_multiplier(PerkManager.STAT_BATTLE_ATTACK),
		"soldier_dmg": c.base_attack * 2.0 * PerkManager.get_multiplier(PerkManager.STAT_BATTLE_ATTACK),
		"worker_hp":    c.base_health * 0.5,
		"soldier_hp":   c.base_health,
		"speed":        c.base_speed,
		"aggression":   c.aggression,
		"cohesion":     c.cohesion,
		"armor":       c.base_defense * PerkManager.get_multiplier(PerkManager.STAT_BATTLE_DEFENSE),
		"venom":        c.venom,
		"queen_buff":   c.queen_buff,
		"panic_resist": c.panic_resist,
	}

func _tick(atk: Dictionary, dfd: Dictionary, luck: float, intensity: float) -> Dictionary:
	var engaged    = max(2, int(_total(atk) * 0.12 * intensity))
	var sol        = min(atk.soldiers, int(engaged * 0.3))
	var wor        = engaged - sol
	var raw        = (wor * atk.worker_dmg) + (sol * atk.soldier_dmg)
	raw += atk.venom * engaged
	raw *= 1.0 + atk.cohesion * 0.3
	if atk.queen_alive: raw *= atk.queen_buff
	raw *= luck
	raw *= 0.5 + (atk.morale / 100.0) * 0.5
	raw *= randf_range(1 - DAMAGE_VARIANCE, 1 + DAMAGE_VARIANCE)
	var is_crit = randf() < CRIT_CHANCE
	if is_crit: raw *= 2.0
	raw = max(engaged, raw - (engaged * dfd.armor))
	var avg_hp     = (dfd.worker_hp + dfd.soldier_hp * 0.3) / 1.3
	var casualties = min(max(1, int(raw / avg_hp)), _total(dfd))
	if dfd.workers >= casualties:
		dfd.workers -= casualties
	else:
		var sol_dead = casualties - dfd.workers
		dfd.workers  = 0
		dfd.soldiers = max(0, dfd.soldiers - sol_dead)
	var loss_pct = float(casualties) / max(1, _total(dfd) + casualties)
	dfd.morale   = max(0, dfd.morale - loss_pct * 60 * (1.0 - dfd.panic_resist))
	return {"casualties": casualties, "crit": is_crit}

func _total(c: Dictionary) -> int:
	return c.workers + c.soldiers

func _pct(c: Dictionary) -> float:
	return float(_total(c)) / max(1, c.max_force)

func _midpoint_line(a: Dictionary, b: Dictionary) -> String:
	if _total(a) > _total(b):   return "Your colony is pushing them back!"
	elif _total(b) > _total(a): return "%s has the upper hand..." % b.name
	else:                       return "Evenly matched — this could go either way."

func _late_line(a: Dictionary, b: Dictionary) -> String:
	if _pct(b) < 0.3:   return "The enemy is crumbling — press the attack!"
	elif _pct(a) < 0.3: return "Your colony is barely holding on..."
	else:               return "Both sides fighting to the last ant."
