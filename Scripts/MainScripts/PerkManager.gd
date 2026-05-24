extends Node

# Max perks active at once
const MAX_PERKS: int = 3

# Active perks by perk id
var active_perks: Dictionary = {}

func activate_perk(perk: PerkDef) -> bool:
	if active_perks.size() >= MAX_PERKS:
		return false  # Slots full
	
	active_perks[perk.id] = perk
	EventBus.perk_activated.emit(perk.id)
	return true

func remove_perk(id: String) -> void:
	active_perks.erase(id)

func get_multiplier(stat_name: String) -> float:
	var total: float = 1.0
	for id in active_perks:
		var perk: PerkDef = active_perks[id]
		if perk.stat_target == stat_name:
			total *= perk.multiplier
	return total

func clear_perks() -> void:
	active_perks.clear()
