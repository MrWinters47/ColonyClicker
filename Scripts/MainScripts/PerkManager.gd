extends Node

# =============================================================================
# ARTIFACT INVENTORY + EQUIP + REWARDS
# Artifacts ARE perks — one stat-boosting collectible type (PerkDef).
# Single source of truth for: what exists (catalog), what you own (inventory),
# and what's active (equipped slots).
# =============================================================================

# ─── How many artifacts can be equipped at once
const MAX_SLOTS: int = 3

# ─── Reward odds by rarity — higher = more common (mirrors your FoodNode weights)
var RARITY_WEIGHTS := {
	PerkDef.Rarity.COMMON:    60,
	PerkDef.Rarity.RARE:      25,
	PerkDef.Rarity.EPIC:      12,
	PerkDef.Rarity.LEGENDARY:  3,
}

# ─── State
var _catalog: Dictionary = {}   # id -> PerkDef   (everything that can drop)
var _owned: Dictionary   = {}   # id -> int       (your inventory, counts dupes)
var _equipped: Array     = []   # ids currently active (max MAX_SLOTS)

func _ready() -> void:
	_register_catalog()

# =============================================================================
# CATALOG — every artifact in the game. ADD NEW ONES HERE, one line each.
# Args: id, name, desc, rarity, stat_target, multiplier
# =============================================================================
func _register_catalog() -> void:
	_register("royal_jelly",    "Royal Jelly",     "Foraging yields +15% sucrose.", PerkDef.Rarity.COMMON,    "sucrose_gain",   1.15)
	_register("swift_mandible", "Swift Mandibles", "Ants forage 20% faster.",       PerkDef.Rarity.RARE,      "forage_speed",   1.20)
	_register("brood_surge",    "Brood Surge",     "Spawn speed +25%.",             PerkDef.Rarity.RARE,      "spawn_speed",    1.25)
	_register("war_pheromone",  "War Pheromone",   "Battle attack +30%.",           PerkDef.Rarity.EPIC,      "battle_attack",  1.30)
	_register("chitin_plate",   "Chitin Plating",  "Battle defense +30%.",          PerkDef.Rarity.EPIC,      "battle_defense", 1.30)
	_register("ancient_amber",  "Ancient Amber",   "All sucrose gain +50%.",        PerkDef.Rarity.LEGENDARY, "sucrose_gain",   1.50)

func _register(id: String, name: String, desc: String, rarity: PerkDef.Rarity, stat: String, mult: float) -> void:
	var a = PerkDef.new()
	a.id           = id
	a.display_name = name
	a.description  = desc
	a.rarity       = rarity
	a.stat_target  = stat
	a.multiplier   = mult
	_catalog[id]   = a

# =============================================================================
# INVENTORY (owned)
# =============================================================================
func grant_artifact(id: String) -> void:
	# ─── THE reward hook — call this to drop an artifact into the inventory
	if not _catalog.has(id):
		push_warning("PerkManager: tried to grant unknown artifact '" + id + "'")
		return
	_owned[id] = _owned.get(id, 0) + 1
	EventBus.artifact_granted.emit(id)

func is_owned(id: String) -> bool:
	return _owned.get(id, 0) > 0

func get_owned_count(id: String) -> int:
	return _owned.get(id, 0)

func get_owned_ids() -> Array:
	return _owned.keys()

# =============================================================================
# EQUIP / UNEQUIP (active slots)
# =============================================================================
func equip(id: String) -> bool:
	if not is_owned(id):              return false   # can't equip what you don't have
	if _equipped.has(id):             return false   # already on
	if _equipped.size() >= MAX_SLOTS: return false   # no free slots
	_equipped.append(id)
	EventBus.artifact_equipped.emit(id)
	return true

func unequip(id: String) -> void:
	if _equipped.has(id):
		_equipped.erase(id)
		EventBus.artifact_unequipped.emit(id)

func is_equipped(id: String) -> bool:
	return _equipped.has(id)

func get_equipped_ids() -> Array:
	return _equipped.duplicate()

func free_slots() -> int:
	return MAX_SLOTS - _equipped.size()

# =============================================================================
# REWARDS
# =============================================================================
func roll_reward() -> String:
	# ─── Weighted-random drop by rarity. Returns the granted id ("" if empty).
	var pool := _catalog.values()
	if pool.is_empty():
		return ""
	var total := 0
	for a in pool:
		total += int(RARITY_WEIGHTS.get(a.rarity, 1))
	var roll := randi() % total
	var cumulative := 0
	for a in pool:
		cumulative += int(RARITY_WEIGHTS.get(a.rarity, 1))
		if roll < cumulative:
			grant_artifact(a.id)
			return a.id
	return ""

# =============================================================================
# LOOKUPS (for the UI) + STAT API
# =============================================================================
func get_def(id: String) -> PerkDef:
	return _catalog.get(id, null)

func get_catalog() -> Array:
	return _catalog.values()

func get_multiplier(stat_name: String) -> float:
	# ─── Combined multiplier from all EQUIPPED artifacts for one stat
	var total: float = 1.0
	for id in _equipped:
		var a: PerkDef = _catalog.get(id, null)
		if a and a.stat_target == stat_name:
			total *= a.multiplier
	return total

# =============================================================================
# BACKWARDS-COMPAT SHIMS (your old API) — safe to delete if nothing calls them
# =============================================================================
func activate_perk(perk: PerkDef) -> bool:
	if perk == null:
		return false
	if not _catalog.has(perk.id):
		_catalog[perk.id] = perk
	grant_artifact(perk.id)
	EventBus.perk_activated.emit(perk.id)
	return equip(perk.id)

func remove_perk(id: String) -> void:
	unequip(id)

func clear_perks() -> void:
	_equipped.clear()
