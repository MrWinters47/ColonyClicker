extends Node
# Autoload: PerkManager
# The binder (registry) + the equipped deck (active_perks).

const MAX_PERKS: int = 3

# Stat constants — use these everywhere. No string-typo bugs.
const STAT_SUCROSE_GAIN := "sucrose_gain"
const STAT_FORAGE_SPEED := "forage_speed"
const STAT_SPAWN_SPEED := "spawn_speed"
const STAT_BATTLE_ATTACK := "battle_attack"
const STAT_BATTLE_DEFENSE := "battle_defense"

var perk_registry: Dictionary = {}   # every perk in the game, by id
var active_perks: Dictionary = {}    # currently equipped, by id

func _ready() -> void:
	_register_perks()

# ---- THE BINDER ----
# One line per perk. New perk = new line here. Nowhere else.
func _register_perks() -> void:
	# ─── One perk per queen — unlocked by defeating her
	_def(PerkDef.create("perk_fire",       "Ember Sting",        "+10% battle attack",          STAT_BATTLE_ATTACK,  1.10, PerkDef.Rarity.COMMON))
	_def(PerkDef.create("perk_argentine",  "Supercolony",        "Spawn bar fills 15% faster",  STAT_SPAWN_SPEED,    1.15, PerkDef.Rarity.COMMON))
	_def(PerkDef.create("perk_pavement",   "Hardened Shell",     "+20% battle defense",         STAT_BATTLE_DEFENSE, 1.20, PerkDef.Rarity.COMMON))
	_def(PerkDef.create("perk_bullet",     "Neurotoxin",         "+25% battle attack",          STAT_BATTLE_ATTACK,  1.25, PerkDef.Rarity.RARE))
	_def(PerkDef.create("perk_leafcutter", "Leafcutter Economy", "+50% sucrose per haul",       STAT_SUCROSE_GAIN,   1.50, PerkDef.Rarity.RARE))
	_def(PerkDef.create("perk_army",       "Relentless Legion",  "Ants forage 15% faster",      STAT_FORAGE_SPEED,   1.15, PerkDef.Rarity.RARE))
	_def(PerkDef.create("perk_weaver",     "Living Bridge",      "+15% battle defense",         STAT_BATTLE_DEFENSE, 1.15, PerkDef.Rarity.RARE))
	_def(PerkDef.create("perk_driver",     "Fearless March",     "+20% battle attack",          STAT_BATTLE_ATTACK,  1.20, PerkDef.Rarity.EPIC))
	_def(PerkDef.create("perk_jack",       "Leaping Strike",     "+30% battle attack",          STAT_BATTLE_ATTACK,  1.30, PerkDef.Rarity.EPIC))
	_def(PerkDef.create("perk_trapjaw",    "Snap Jaws",          "+25% battle attack",          STAT_BATTLE_ATTACK,  1.25, PerkDef.Rarity.EPIC))
	_def(PerkDef.create("perk_bulldog",    "Iron Hide",          "+30% battle defense",         STAT_BATTLE_DEFENSE, 1.30, PerkDef.Rarity.LEGENDARY))
	_def(PerkDef.create("perk_giant",      "Apex Ascendancy",    "+25% sucrose per haul",       STAT_SUCROSE_GAIN,   1.25, PerkDef.Rarity.LEGENDARY))

func _def(perk: PerkDef) -> void:
	perk_registry[perk.id] = perk

# ---- EQUIP / UNEQUIP ----
func activate_perk_by_id(id: String) -> bool:
	if not perk_registry.has(id):
		push_warning("PerkManager: no perk with id '%s'" % id)
		return false
	return activate_perk(perk_registry[id])

func activate_perk(perk: PerkDef) -> bool:
	if not is_unlocked(perk.id):
		return false  # ← can't equip what you haven't earned
	if active_perks.has(perk.id):
		return true
	# ... rest unchanged
	if active_perks.has(perk.id):
		return true  # already equipped — don't eat a slot
	if active_perks.size() >= MAX_PERKS:
		return false  # deck full
	active_perks[perk.id] = perk
	EventBus.perks_changed.emit()
	return true

func remove_perk(id: String) -> void:
	if active_perks.erase(id):
		EventBus.perks_changed.emit()

func clear_perks() -> void:
	active_perks.clear()
	EventBus.perks_changed.emit()

# ---- READING ----
func get_multiplier(stat_name: String) -> float:
	var total: float = 1.0
	for id in active_perks:
		var perk: PerkDef = active_perks[id]
		if perk.stat_target == stat_name:
			total *= perk.multiplier
	return total

func get_active_list() -> Array:
	return active_perks.values()

func is_active(id: String) -> bool:
	return active_perks.has(id)


# ---- OWNERSHIP — perks earned by defeating queens ----
var unlocked_perks: Dictionary = {}   # id -> true

func unlock_perk_by_id(id: String) -> bool:
	if not perk_registry.has(id):
		push_warning("PerkManager: no perk with id '%s'" % id)
		return false
	if unlocked_perks.has(id):
		return true
	unlocked_perks[id] = true
	EventBus.perks_changed.emit()
	return true

func is_unlocked(id: String) -> bool:
	return unlocked_perks.has(id)
