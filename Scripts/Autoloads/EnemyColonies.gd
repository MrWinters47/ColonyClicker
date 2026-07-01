extends Node

var current_index: int = 0

var queens: Array = [

	# ── 1 ── FIRE ANT
	{
		"name": "Fire Ant", "colony_name": "The Fire Colony",
		"lore": "Aggressive red ants that bite first. A solid first fight, but no real surprises.",
		"perk": "Ember Sting: Soldiers deal +10% damage.",
		"perk_id": "perk_fire",
		"color": Color(0.80, 0.20, 0.10), "carry_mul": 1.0,
		"workers": 800, "soldiers": 200, "worker_dmg": 10, "soldier_dmg": 25,
		"worker_hp": 32, "soldier_hp": 75, "speed": 1.2, "aggression": 0.85,
		"cohesion": 0.4, "armor": 2, "venom": 5, "queen_buff": 1.05,
		"panic_resist": 0.5, "portrait": "res://Assets/Art/fire_ant.png",
	},

	# ── 2 ── ARGENTINE ANT
	{
		"name": "Argentine Ant", "colony_name": "The Argentine Colony",
		"lore": "Endless tiny workers in tight columns. Individually weak, overwhelming in number.",
		"perk": "Supercolony: +1 ant per spawn cycle.",
		"perk_id": "perk_argentine",
		"color": Color(0.55, 0.40, 0.25), "carry_mul": 1.1,
		"workers": 2000, "soldiers": 100, "worker_dmg": 8, "soldier_dmg": 18,
		"worker_hp": 25, "soldier_hp": 60, "speed": 1.1, "aggression": 0.9,
		"cohesion": 0.6, "armor": 1, "venom": 2, "queen_buff": 1.05,
		"panic_resist": 0.4, "portrait": "res://Assets/Art/argentine_ant.png",
	},

	# ── 3 ── PAVEMENT ANT
	{
		"name": "Pavement Ant", "colony_name": "The Pavement Colony",
		"lore": "Slow, stubborn, heavily armoured. They hold ground rather than chase.",
		"perk": "Hardened Shell: Colony defense +20%.",
		"perk_id": "perk_pavement",
		"color": Color(0.45, 0.45, 0.50), "carry_mul": 1.15,
		"workers": 600, "soldiers": 300, "worker_dmg": 9, "soldier_dmg": 20,
		"worker_hp": 40, "soldier_hp": 90, "speed": 0.9, "aggression": 0.6,
		"cohesion": 0.7, "armor": 5, "venom": 1, "queen_buff": 1.08,
		"panic_resist": 0.6, "portrait": "res://Assets/Art/pavement_ant.png",
	},

	# ── 4 ── BULLET ANT
	{
		"name": "Bullet Ant", "colony_name": "The Bullet Colony",
		"lore": "Their numbers are small but each sting is catastrophic. Do not underestimate them.",
		"perk": "Neurotoxin: 10% chance to double damage each round.",
		"perk_id": "perk_bullet",
		"color": Color(0.30, 0.20, 0.15), "carry_mul": 1.25,
		"workers": 300, "soldiers": 150, "worker_dmg": 18, "soldier_dmg": 45,
		"worker_hp": 60, "soldier_hp": 120, "speed": 0.8, "aggression": 0.75,
		"cohesion": 0.5, "armor": 3, "venom": 9, "queen_buff": 1.10,
		"panic_resist": 0.7, "portrait": "res://Assets/Art/bullet_ant.png",
	},

	# ── 5 ── LEAFCUTTER ANT
	{
		"name": "Leafcutter Ant", "colony_name": "The Leafcutter Colony",
		"lore": "Master foragers who carry many times their weight. Their economy is unmatched.",
		"perk": "Leafcutter Efficiency: Carry capacity +50%.",
		"perk_id": "perk_leafcutter",
		"color": Color(0.20, 0.70, 0.35), "carry_mul": 1.5,
		"workers": 1500, "soldiers": 400, "worker_dmg": 12, "soldier_dmg": 28,
		"worker_hp": 45, "soldier_hp": 100, "speed": 1.0, "aggression": 0.65,
		"cohesion": 0.8, "armor": 3, "venom": 2, "queen_buff": 1.12,
		"panic_resist": 0.5, "portrait": "res://Assets/Art/leafcutter_ant.png",
	},

	# ── 6 ── ARMY ANT
	{
		"name": "Army Ant", "colony_name": "The Army Colony",
		"lore": "They never stop advancing. A living tide that consumes everything in its path.",
		"perk": "Relentless Legion: Ants return 15% faster.",
		"perk_id": "perk_army",
		"color": Color(0.35, 0.25, 0.20), "carry_mul": 1.4,
		"workers": 3000, "soldiers": 500, "worker_dmg": 9, "soldier_dmg": 22,
		"worker_hp": 30, "soldier_hp": 70, "speed": 1.3, "aggression": 0.95,
		"cohesion": 0.5, "armor": 2, "venom": 3, "queen_buff": 1.08,
		"panic_resist": 0.8, "portrait": "res://Assets/Art/army_ant.png",
	},

	# ── 7 ── WEAVER ANT
	{
		"name": "Weaver Ant", "colony_name": "The Weaver Colony",
		"lore": "They build living bridges from their own bodies and fight as a single coordinated mind.",
		"perk": "Living Bridge: Colony cohesion +25% in battle.",
		"perk_id": "perk_weaver",
		"color": Color(0.60, 0.75, 0.20), "carry_mul": 1.45,
		"workers": 1000, "soldiers": 400, "worker_dmg": 11, "soldier_dmg": 26,
		"worker_hp": 38, "soldier_hp": 85, "speed": 1.2, "aggression": 0.8,
		"cohesion": 0.9, "armor": 2, "venom": 4, "queen_buff": 1.10,
		"panic_resist": 0.5, "portrait": "res://Assets/Art/weaver_ant.png",
	},

	# ── 8 ── DRIVER ANT
	{
		"name": "Driver Ant", "colony_name": "The Driver Colony",
		"lore": "The largest raiding columns on earth. They feel no fear and break no ranks.",
		"perk": "Fearless March: Colony cannot rout.",
		"perk_id": "perk_driver",
		"color": Color(0.15, 0.12, 0.10), "carry_mul": 1.5,
		"workers": 5000, "soldiers": 300, "worker_dmg": 8, "soldier_dmg": 20,
		"worker_hp": 28, "soldier_hp": 65, "speed": 0.9, "aggression": 0.95,
		"cohesion": 0.4, "armor": 1, "venom": 2, "queen_buff": 1.05,
		"panic_resist": 0.9, "portrait": "res://Assets/Art/driver_ant.png",
	},

	# ── 9 ── JACK JUMPER
	{
		"name": "Jack Jumper", "colony_name": "The Jack Jumper Colony",
		"lore": "They leap. Lightning-fast strikes that land before you see them coming.",
		"perk": "Leaping Strike: Colony attack speed +30%.",
		"perk_id": "perk_jack",
		"color": Color(0.10, 0.10, 0.10), "carry_mul": 1.55,
		"workers": 400, "soldiers": 300, "worker_dmg": 15, "soldier_dmg": 35,
		"worker_hp": 50, "soldier_hp": 110, "speed": 1.8, "aggression": 0.85,
		"cohesion": 0.4, "armor": 2, "venom": 8, "queen_buff": 1.10,
		"panic_resist": 0.6, "portrait": "res://Assets/Art/jack_jumper.png",
	},

	# ── 10 ── TRAP-JAW ANT
	{
		"name": "Trap-jaw Ant", "colony_name": "The Trap-jaw Colony",
		"lore": "Their jaws snap shut faster than anything in nature. One bite can end a soldier.",
		"perk": "Snap Jaws: Soldier damage +25%.",
		"perk_id": "perk_trapjaw",
		"color": Color(0.50, 0.30, 0.10), "carry_mul": 1.6,
		"workers": 500, "soldiers": 350, "worker_dmg": 16, "soldier_dmg": 50,
		"worker_hp": 55, "soldier_hp": 115, "speed": 1.5, "aggression": 0.8,
		"cohesion": 0.5, "armor": 3, "venom": 6, "queen_buff": 1.12,
		"panic_resist": 0.65, "portrait": "res://Assets/Art/trapjaw_ant.png",
	},

	# ── 11 ── BULLDOG ANT
	{
		"name": "Bulldog Ant", "colony_name": "The Bulldog Colony",
		"lore": "Huge, armoured and relentless. Each one is worth ten lesser ants in a brawl.",
		"perk": "Iron Hide: Colony health +30%.",
		"perk_id": "perk_bulldog",
		"color": Color(0.60, 0.15, 0.05), "carry_mul": 1.8,
		"workers": 600, "soldiers": 400, "worker_dmg": 20, "soldier_dmg": 55,
		"worker_hp": 80, "soldier_hp": 160, "speed": 1.0, "aggression": 0.9,
		"cohesion": 0.6, "armor": 8, "venom": 5, "queen_buff": 1.15,
		"panic_resist": 0.75, "portrait": "res://Assets/Art/bulldog_ant.png",
	},

	# ── 12 ── GIANT FOREST ANT
	{
		"name": "Giant Forest Ant", "colony_name": "The Giant Forest Colony",
		"lore": "The apex colony. Vast, armoured, venomous, coordinated. None have ever defeated them.",
		"perk": "Apex Ascendancy: All stats permanently +25%. Colony Clicker complete.",
		"perk_id": "perk_giant",
		"color": Color(0.05, 0.30, 0.10), "carry_mul": 2.5,
		"workers": 2000, "soldiers": 800, "worker_dmg": 25, "soldier_dmg": 65,
		"worker_hp": 100, "soldier_hp": 200, "speed": 1.3, "aggression": 0.9,
		"cohesion": 0.7, "armor": 8, "venom": 8, "queen_buff": 1.20,
		"panic_resist": 0.8, "portrait": "res://Assets/Art/giant_forest_ant.png",
	},
]

func get_current() -> Dictionary:
	return queens[current_index]

func advance() -> void:
	current_index = min(current_index + 1, queens.size() - 1)

func is_final() -> bool:
	return current_index >= queens.size() - 1

func reset() -> void:
	current_index = 0

func build_colony_stats(q: Dictionary) -> ColonyStats:
	var s := ColonyStats.new()
	s.colony_name      = q.colony_name
	s.species          = q.name
	s.base_health      = q.worker_hp * 2.0
	s.base_attack      = q.worker_dmg
	s.base_defense     = q.armor
	s.base_speed       = q.speed
	s.base_forage_rate = q.carry_mul
	s.venom            = q.venom
	s.cohesion         = q.cohesion
	s.aggression       = q.aggression
	s.panic_resist     = q.panic_resist
	s.queen_buff       = q.queen_buff
	return s

# ─── SAVE: which queen you're up to
func save_data() -> Dictionary:
	return {"current_index": current_index}

func load_data(d: Dictionary) -> void:
	current_index = clamp(int(d.get("current_index", 0)), 0, queens.size() - 1)
