extends Resource
class_name UpgradeDef

# ─── Identity
@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""

# ─── Stat effect — informational; real effect is dispatched in MainUI._apply_upgrade
@export var stat_target: String = ""
@export var value: float = 0.0
@export var is_percent: bool = false

# ─── Cost — final cost = base_cost × cost_multiplier ^ current_level
@export var base_cost: float = 50.0
@export var cost_multiplier: float = 1.5

# ─── How many times the player can buy this
@export var max_level: int = 10

# ─── Gating — leave prerequisite_id blank for tier 1 (always unlocked)
@export var prerequisite_id: String = ""
@export var prerequisite_level: int = 0
