class_name ColonyManager
extends Node

var stats: ColonyStats = null
var upgrade_levels: Dictionary = {}
var active_perks: Dictionary = {}

func load_colony(colony_stats: ColonyStats) -> void:
	stats = colony_stats
	upgrade_levels.clear()
	active_perks.clear()
	GameManager.active_colony = stats
	EventBus.colony_loaded.emit(stats)

func get_stat(stat_name: String) -> float:
	var base = stats.get(stat_name)

	for id in upgrade_levels:
		var upgrade: UpgradeDef = UpgradeManager.get_def(id)
		if upgrade.stat_target == stat_name and not upgrade.is_percent:
			base += upgrade.value * upgrade_levels[id]

	for id in active_perks:
		var perk: PerkDef = active_perks[id]
		if perk.stat_target == stat_name:
			base *= perk.multiplier

	return base
