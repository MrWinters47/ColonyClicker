extends Node

const DAMAGE_VARIANCE   = 0.06
const CRIT_CHANCE       = 0.08
const ROUT_THRESHOLD    = 12.0
const ROUT_CHANCE       = 0.08
const QUEEN_KILL_CHANCE = 0.020
const MAX_TICKS         = 500
const ANT_FORCE_MULT    = 500.0  # each visible ant = 80 battle units

func resolve(enemy: Dictionary) -> Dictionary:
	var player = _build_player_dict()
	var a = player.duplicate()
	var b = enemy.duplicate()
	a["max_force"] = a.workers + a.soldiers
	b["max_force"] = b.workers + b.soldiers
	a["morale"]      = 100.0
	b["morale"]      = 100.0
	a["queen_alive"] = GameManager.queen_alive
	b["queen_alive"] = true

	var a_luck = randf_range(0.95, 1.05)
	var b_luck = randf_range(0.95, 1.05)
	var log: Array = []
	var routed = ""

	for tick in MAX_TICKS:
		if _total(a) <= 0 or _total(b) <= 0:
			break

		var progress  = float(tick) / MAX_TICKS
		var intensity = 0.4 + progress * 1.0
		var a_attacks = randf() < (a.speed / (a.speed + b.speed))

		if a_attacks:
			var result = _tick(a, b, a_luck, intensity)
			if result.crit and tick % 18 == 0:
				log.append({"text": "CRIT! Your colony lands a devastating blow!", "pf": _total(a), "ef": _total(b)})
		else:
			var result = _tick(b, a, b_luck, intensity)
			if result.crit and tick % 18 == 0:
				log.append({"text": "CRIT! %s strikes hard!" % b.name, "pf": _total(a), "ef": _total(b)})

		# Narrative snapshots at key moments
		if tick == 30:
			log.append({"text": "Both colonies clash — the ground shakes.", "pf": _total(a), "ef": _total(b)})
		if tick == 60:
			log.append({"text": _midpoint_line(a, b), "pf": _total(a), "ef": _total(b)})
		if tick == 100:
			log.append({"text": _late_line(a, b), "pf": _total(a), "ef": _total(b)})

		# Queen kill
		if progress > 0.66:
			if b.queen_alive and _pct(b) < 0.25 and randf() < QUEEN_KILL_CHANCE:
				b.queen_alive = false
				b.morale = max(0, b.morale - 30)
				log.append({"text": "Their queen has been killed! Enemy morale collapses!", "pf": _total(a), "ef": _total(b)})
			if a.queen_alive and _pct(a) < 0.25 and randf() < QUEEN_KILL_CHANCE:
				a.queen_alive = false
				a.morale = max(0, a.morale - 30)
				log.append({"text": "Your queen has fallen! Hold the line!", "pf": _total(a), "ef": _total(b)})

		# Rout check
		if b.morale < ROUT_THRESHOLD and randf() < ROUT_CHANCE * (1.0 - b.aggression):
			log.append({"text": "%s breaks and flees!" % b.name, "pf": _total(a), "ef": _total(b)})
			routed = "enemy"
			break
		if a.morale < ROUT_THRESHOLD and randf() < ROUT_CHANCE * (1.0 - a.aggression):
			log.append({"text": "Your colony breaks under pressure!", "pf": _total(a), "ef": _total(b)})
			routed = "player"
			break

	var winner = ""
	var method = ""
	if routed == "enemy":
		winner = "player"; method = "rout"
	elif routed == "player":
		winner = "enemy"; method = "rout"
	elif _total(a) > _total(b):
		winner = "player"
		method = "annihilation" if _total(b) == 0 else "field control"
	else:
		winner = "enemy"
		method = "annihilation" if _total(a) == 0 else "field control"

	log.append({"text": "--- BATTLE OVER ---", "pf": _total(a), "ef": _total(b)})
	if winner == "player":
		log.append({"text": "VICTORY! %s colony defeated!" % b.name, "pf": _total(a), "ef": _total(b), "result": "player"})
	else:
		log.append({"text": "DEFEAT. Regroup and try again.", "pf": _total(a), "ef": _total(b), "result": "enemy"})

	return {
		"winner":       winner,
		"method":       method,
		"player_loss":  1.0 - _pct(a),
		"enemy_loss":   1.0 - _pct(b),
		"log":          log,
		"max_player":   a.max_force,
		"max_enemy":    b.max_force
	}

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
		"worker_dmg":   c.base_attack,
		"soldier_dmg":  c.base_attack * 2.0,
		"worker_hp":    c.base_health * 0.5,
		"soldier_hp":   c.base_health,
		"speed":        c.base_speed,
		"aggression":   c.aggression,
		"cohesion":     c.cohesion,
		"armor":        c.base_defense,
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
	if _total(a) > _total(b): return "Your colony is pushing them back!"
	elif _total(b) > _total(a): return "%s has the upper hand..." % b.name
	else: return "Evenly matched — this could go either way."

func _late_line(a: Dictionary, b: Dictionary) -> String:
	if _pct(b) < 0.3: return "The enemy is crumbling — press the attack!"
	elif _pct(a) < 0.3: return "Your colony is barely holding on..."
	else: return "Both sides fighting to the last ant."
