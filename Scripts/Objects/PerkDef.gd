class_name PerkDef
extends Resource
# One perk's data. A single artifact card.

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var stat_target: String = ""
@export var multiplier: float = 1.0
@export var rarity: Rarity = Rarity.COMMON

static func create(p_id: String, p_name: String, p_desc: String, p_stat: String, p_mult: float, p_rarity: Rarity = Rarity.COMMON) -> PerkDef:
	var def := PerkDef.new()
	def.id = p_id
	def.display_name = p_name
	def.description = p_desc
	def.stat_target = p_stat
	def.multiplier = p_mult
	def.rarity = p_rarity
	return def
