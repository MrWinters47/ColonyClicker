extends Resource
class_name PerkDef

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""

# What stat this perk affects
@export var stat_target: String = ""

# Perks are always percentage based (they're powerful)
@export var multiplier: float = 1.0

# Carries through prestige
@export var is_permanent: bool = true
