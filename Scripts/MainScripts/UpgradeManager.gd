extends Node

# ─── Registered defs (the catalog) and their current purchased levels
var _defs: Dictionary   = {}   # id -> UpgradeDef
var _levels: Dictionary = {}   # id -> int

# ─── Called by UpgradePanel on startup to register every upgrade in the game
func register_def(upgrade: UpgradeDef) -> void:
	_defs[upgrade.id] = upgrade
	if not _levels.has(upgrade.id):
		_levels[upgrade.id] = 0

# ─── Lookup helpers used by cards and the stat system
func get_def(id: String) -> UpgradeDef:
	return _defs.get(id, null)

func get_all_defs() -> Array:
	return _defs.values()

func get_level(id: String) -> int:
	return _levels.get(id, 0)

# ─── Live cost — scales each level by cost_multiplier
func get_cost(id: String) -> float:
	var upgrade = get_def(id)
	if not upgrade:
		return 0.0
	return upgrade.base_cost * pow(upgrade.cost_multiplier, get_level(id))

# ─── Gating — true if prereq is met (or there isn't one)
func is_unlocked(id: String) -> bool:
	var upgrade = get_def(id)
	if not upgrade:
		return false
	if upgrade.prerequisite_id == "":
		return true
	return get_level(upgrade.prerequisite_id) >= upgrade.prerequisite_level

# ─── Can the player buy this right now? Checks unlock, max, and sucrose
func can_purchase(id: String) -> bool:
	var upgrade = get_def(id)
	if not upgrade:                            return false
	if get_level(id) >= upgrade.max_level:     return false
	if not is_unlocked(id):                    return false
	if GameManager.sucrose < get_cost(id):     return false
	return true

# ─── THE ONE payment path — cards call this, nothing else spends sucrose for upgrades
func purchase(id: String) -> bool:
	if not can_purchase(id):
		return false
	var cost = get_cost(id)
	if not GameManager.spend_sucrose(cost):
		return false
	_levels[id] = get_level(id) + 1
	EventBus.upgrade_purchased.emit(id)
	return true

# ─── Wipe all levels (called on prestige)
func reset_levels() -> void:
	for id in _levels.keys():
		_levels[id] = 0
