extends Resource
class_name PerkDef

# ─── Rarity tiers — drives reward odds and card colour
enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

# ─── Identity
@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""

# ─── Visual — defaults to Godot's icon as a placeholder until you draw art
@export var icon_path: String = "res://icon.svg"
@export var rarity: Rarity = Rarity.COMMON

# ─── What stat this artifact affects (data-only until you wire it to stats)
@export var stat_target: String = ""

# ─── Artifacts are percentage based (they're powerful)
@export var multiplier: float = 1.0

# ─── Carries through prestige
@export var is_permanent: bool = true

static func create(p_id: String, p_name: String, p_desc: String, p_stat: String, p_mult: float, p_rarity: Rarity = Rarity.COMMON) -> PerkDef:
	var def := PerkDef.new()
	def.id = p_id
	def.display_name = p_name
	def.description = p_desc
	def.stat_target = p_stat
	def.multiplier = p_mult
	def.rarity = p_rarity
	return def
