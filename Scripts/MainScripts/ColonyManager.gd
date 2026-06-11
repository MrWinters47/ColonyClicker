class_name ColonyManager
extends Node

# ─── Base species stats and currently-equipped perks
var stats: ColonyStats     = null
var active_perks: Dictionary = {}

# ─── Load a colony — also wipes upgrade levels (prestige reset)
func load_colony(colony_stats: ColonyStats) -> void:
	stats = colony_stats
	active_perks.clear()
	UpgradeManager.reset_levels()
	GameManager.set_colony(stats)

# ─── The single function that computes any stat with upgrades + perks applied
func get_stat(stat_name: String) -> float:
	var base = stats.get(stat_name)

	# ─── Flat additions from upgrades — level pulled from UpgradeManager
	for upgrade in UpgradeManager.get_all_defs():
		if upgrade.stat_target == stat_name and not upgrade.is_percent:
			base += upgrade.value * UpgradeManager.get_level(upgrade.id)

	# ─── Percentage multipliers from perks layered on top
	for id in active_perks:
		var perk: PerkDef = active_perks[id]
		if perk.stat_target == stat_name:
			base *= perk.multiplier

	return base


func reset() -> void:
	active_perks.clear()
	UpgradeManager.reset_levels()
