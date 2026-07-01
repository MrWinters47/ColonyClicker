extends Node

# Currency
signal sucrose_changed(new_amount: float)

# Colony
signal colony_loaded(colony_stats)
signal upgrade_purchased(upgrade_id: String)
signal perk_activated(perk_id: String)

# Artifacts (perks/loot)
signal artifact_granted(id: String)
signal artifact_equipped(id: String)
signal artifact_unequipped(id: String)

# Ants
signal ant_spawned(ant)
signal ant_died(ant)

# Battle
signal battle_started()
signal battle_ended(won: bool)

# Scout
signal scout_sent()
signal scout_returned(reward: Dictionary)

# Prestige
signal prestige_triggered(new_colony)

# Game
signal game_saved()
signal game_loaded()


signal perks_changed()   # ← fires on any unlock, equip, or unequip

signal boost_changed(fill: float)
signal boost_activated()
signal boost_ended()
