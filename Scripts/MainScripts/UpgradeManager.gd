extends Node

var _defs: Dictionary = {}

func register_def(upgrade: UpgradeDef) -> void:
	_defs[upgrade.id] = upgrade

func get_def(id: String) -> UpgradeDef:
	return _defs.get(id, null)

func get_cost(id: String, current_level: int) -> float:
	var upgrade = get_def(id)
	if not upgrade:
		return 0.0
	return upgrade.base_cost * pow(upgrade.cost_multiplier, current_level)

func purchase(id: String, colony: ColonyManager) -> bool:
	var level = colony.upgrade_levels.get(id, 0)
	var upgrade = get_def(id)
	if not upgrade or level >= upgrade.max_level:
		return false
	var cost = get_cost(id, level)
	if GameManager.spend_sucrose(cost):
		colony.upgrade_levels[id] = level + 1
		EventBus.upgrade_purchased.emit(id)
		return true
	return false
