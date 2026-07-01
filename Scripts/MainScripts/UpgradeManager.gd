extends Node

# ═══════════════════════════════════════════════════════════════════════
# 📋 THE UPGRADE CATALOG — every upgrade in the game is defined HERE.
# This is the one script that holds all upgrades. The panel just DRAWS
# whatever is in this list; this manager handles cost / level / unlocking.
#
# TO ADD AN UPGRADE: copy a block below, change the values. Done.
#   (If it needs to actually DO something custom, also add one line in
#    MainUI._apply_upgrade — there's a note explaining why down there.)
#
#   FIELD          WHAT IT MEANS
#   id             unique key, no spaces. MainUI matches on this for the effect.
#   name           the title shown on the card
#   desc           one-line explanation shown on the card
#   branch         the section it groups under (free text → becomes a header)
#   base_cost      sucrose price at level 0
#   cost_mult      price grows ×this each level   (1.5 = +50% every buy)
#   max_level      how many times it can be bought
#   prereq_id      must own this upgrade first    ("" = available from the start)
#   prereq_level   ...at least this level, before this one unlocks
# ═══════════════════════════════════════════════════════════════════════
const CATALOG := [
	# ── SPEED ───────────────────────────────────────────────────────────
	{
		"id": "faster_legs", "name": "Faster Legs", "branch": "SPEED",
		"desc": "Ants move 10% faster",
		"base_cost": 5.0, "cost_mult": 0.2, "max_level": 10,
		"prereq_id": "", "prereq_level": 0,
	},
	{
		"id": "sprinter_genes", "name": "Sprinter Genes", "branch": "SPEED",
		"desc": "+5% speed and raises the speed cap",
		"base_cost": 25, "cost_mult": 2, "max_level": 5,
		"prereq_id": "faster_legs", "prereq_level": 10,
	},

	# ── SPAWN ───────────────────────────────────────────────────────────
	{
		"id": "faster_hatchery", "name": "Faster Hatchery", "branch": "SPAWN",
		"desc": "Hatch faster — 3.0s down to 1.0s at max",
		"base_cost": 30.0, "cost_mult": 1.4, "max_level": 10,
		"prereq_id": "", "prereq_level": 0,
	},
	{
		"id": "royal_pheromones", "name": "Royal Pheromones", "branch": "SPAWN",
		"desc": "+0.10 bonus ants per hatch",
		"base_cost": 1000.0, "cost_mult": 2.2, "max_level": 10,
		"prereq_id": "faster_hatchery", "prereq_level": 10,
	},

	# ── FORAGING ────────────────────────────────────────────────────────
	{
		"id": "better_nose", "name": "Better Nose", "branch": "FORAGING",
		"desc": "Ants detect food 50% further",
		"base_cost": 75.0, "cost_mult": 1.5, "max_level": 10,
		"prereq_id": "", "prereq_level": 0,
	},
	{
		"id": "hawk_eyes", "name": "Hawk Eyes", "branch": "FORAGING",
		"desc": "+25% food detection radius",
		"base_cost": 2000.0, "cost_mult": 2.0, "max_level": 5,
		"prereq_id": "better_nose", "prereq_level": 10,
	},

	# ── COMMAND ─────────────────────────────────────────────────────────
	{
		"id": "click_influence", "name": "Click Influence", "branch": "COMMAND",
		"desc": "+1 ant follows your rally tap",
		"base_cost": 100.0, "cost_mult": 1.6, "max_level": 10,
		"prereq_id": "", "prereq_level": 0,
	},
	{
		"id": "bigger_colony", "name": "Bigger Colony", "branch": "COMMAND",
		"desc": "Instantly add 20 ants to the colony",
		"base_cost": 200.0, "cost_mult": 1.7, "max_level": 10,
		"prereq_id": "", "prereq_level": 0,
	},
]

# ─── Built from CATALOG at startup; levels track what the player has bought
var _defs: Dictionary   = {}   # id -> UpgradeDef
var _levels: Dictionary = {}   # id -> int

# ─── Autoload _ready runs before any scene, so defs always exist in time
func _ready() -> void:
	_build_catalog()

func _build_catalog() -> void:
	for entry in CATALOG:
		var u := UpgradeDef.new()
		u.id                 = entry.id
		u.display_name       = entry.name
		u.description        = entry.desc
		u.base_cost          = entry.base_cost
		u.cost_multiplier    = entry.cost_mult
		u.max_level          = entry.max_level
		u.prerequisite_id    = entry.prereq_id
		u.prerequisite_level = entry.prereq_level
		register_def(u)

func register_def(upgrade: UpgradeDef) -> void:
	_defs[upgrade.id] = upgrade
	if not _levels.has(upgrade.id):
		_levels[upgrade.id] = 0

# ─── Branch helpers — the panel reads these so CATALOG stays the only source
func get_branch_order() -> Array:
	var seen: Array = []
	for entry in CATALOG:
		if not seen.has(entry.branch):
			seen.append(entry.branch)
	return seen

func get_ids_in_branch(branch: String) -> Array:
	var ids: Array = []
	for entry in CATALOG:
		if entry.branch == branch:
			ids.append(entry.id)
	return ids

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

# ─── THE ONE payment path — cards call this, nothing else spends sucrose
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


# ─── SAVE: dumps ALL levels generically — new upgrades need ZERO save code
func save_data() -> Dictionary:
	return _levels.duplicate()

func load_data(d: Dictionary) -> void:
	for id in d.keys():
		if _defs.has(id):              # skip upgrades that no longer exist
			_levels[id] = int(d[id])
