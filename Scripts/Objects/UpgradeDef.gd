extends Resource
class_name UpgradeDef

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""

# What stat does this upgrade affect
@export var stat_target: String = ""

# Flat increase or percentage multiplier
@export var value: float = 0.0
@export var is_percent: bool = false

# Cost scaling
@export var base_cost: float = 50.0
@export var cost_multiplier: float = 1.5

# Max times this can be levelled up
@export var max_level: int = 10
