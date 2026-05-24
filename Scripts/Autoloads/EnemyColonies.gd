extends Node

var current_index: int = 0

var queens: Array = [
	{"name": "Fire Ant",       "workers": 800,  "soldiers": 200, "worker_dmg": 10, "soldier_dmg": 25, "worker_hp": 32, "soldier_hp": 75,  "speed": 1.2, "aggression": 0.85, "cohesion": 0.4, "armor": 2, "venom": 5,  "queen_buff": 1.05, "panic_resist": 0.5, "portrait": "res://Assets/Art/fire_ant.png"},
	{"name": "Argentine Ant",  "workers": 2000, "soldiers": 100, "worker_dmg": 8,  "soldier_dmg": 18, "worker_hp": 25, "soldier_hp": 60,  "speed": 1.1, "aggression": 0.9,  "cohesion": 0.6, "armor": 1, "venom": 2,  "queen_buff": 1.05, "panic_resist": 0.4, "portrait": "res://Assets/Art/argentine_ant.png"},
	{"name": "Pavement Ant",   "workers": 600,  "soldiers": 300, "worker_dmg": 9,  "soldier_dmg": 20, "worker_hp": 40, "soldier_hp": 90,  "speed": 0.9, "aggression": 0.6,  "cohesion": 0.7, "armor": 5, "venom": 1,  "queen_buff": 1.08, "panic_resist": 0.6, "portrait": "res://Assets/Art/pavement_ant.png"},
	{"name": "Bullet Ant",     "workers": 300,  "soldiers": 150, "worker_dmg": 18, "soldier_dmg": 45, "worker_hp": 60, "soldier_hp": 120, "speed": 0.8, "aggression": 0.75, "cohesion": 0.5, "armor": 3, "venom": 9,  "queen_buff": 1.10, "panic_resist": 0.7, "portrait": "res://Assets/Art/bullet_ant.png"},
	{"name": "Leafcutter Ant", "workers": 1500, "soldiers": 400, "worker_dmg": 12, "soldier_dmg": 28, "worker_hp": 45, "soldier_hp": 100, "speed": 1.0, "aggression": 0.65, "cohesion": 0.8, "armor": 3, "venom": 2,  "queen_buff": 1.12, "panic_resist": 0.5, "portrait": "res://Assets/Art/leafcutter_ant.png"},
	{"name": "Army Ant",       "workers": 3000, "soldiers": 500, "worker_dmg": 9,  "soldier_dmg": 22, "worker_hp": 30, "soldier_hp": 70,  "speed": 1.3, "aggression": 0.95, "cohesion": 0.5, "armor": 2, "venom": 3,  "queen_buff": 1.08, "panic_resist": 0.8, "portrait": "res://Assets/Art/army_ant.png"},
	{"name": "Weaver Ant",     "workers": 1000, "soldiers": 400, "worker_dmg": 11, "soldier_dmg": 26, "worker_hp": 38, "soldier_hp": 85,  "speed": 1.2, "aggression": 0.8,  "cohesion": 0.9, "armor": 2, "venom": 4,  "queen_buff": 1.10, "panic_resist": 0.5, "portrait": "res://Assets/Art/weaver_ant.png"},
	{"name": "Driver Ant",     "workers": 5000, "soldiers": 300, "worker_dmg": 8,  "soldier_dmg": 20, "worker_hp": 28, "soldier_hp": 65,  "speed": 0.9, "aggression": 0.95, "cohesion": 0.4, "armor": 1, "venom": 2,  "queen_buff": 1.05, "panic_resist": 0.9, "portrait": "res://Assets/Art/driver_ant.png"},
	{"name": "Jack Jumper",    "workers": 400,  "soldiers": 300, "worker_dmg": 15, "soldier_dmg": 35, "worker_hp": 50, "soldier_hp": 110, "speed": 1.8, "aggression": 0.85, "cohesion": 0.4, "armor": 2, "venom": 8,  "queen_buff": 1.10, "panic_resist": 0.6, "portrait": "res://Assets/Art/jack_jumper.png"},
	{"name": "Trap-jaw Ant",   "workers": 500,  "soldiers": 350, "worker_dmg": 16, "soldier_dmg": 50, "worker_hp": 55, "soldier_hp": 115, "speed": 1.5, "aggression": 0.8,  "cohesion": 0.5, "armor": 3, "venom": 6,  "queen_buff": 1.12, "panic_resist": 0.65, "portrait": "res://Assets/Art/trapjaw_ant.png"},
	{"name": "Bulldog Ant",    "workers": 600,  "soldiers": 400, "worker_dmg": 20, "soldier_dmg": 55, "worker_hp": 80, "soldier_hp": 160, "speed": 1.0, "aggression": 0.9,  "cohesion": 0.6, "armor": 8, "venom": 5,  "queen_buff": 1.15, "panic_resist": 0.75, "portrait": "res://Assets/Art/bulldog_ant.png"},
	{"name": "Giant Forest",   "workers": 2000, "soldiers": 800, "worker_dmg": 25, "soldier_dmg": 65, "worker_hp": 100,"soldier_hp": 200, "speed": 1.3, "aggression": 0.9,  "cohesion": 0.7, "armor": 8, "venom": 8,  "queen_buff": 1.20, "panic_resist": 0.8, "portrait": "res://Assets/Art/giant_forest_ant.png"},
	{"name": "Fire Ant", "workers": 800, "soldiers": 200, "worker_dmg": 10, "soldier_dmg": 25, "worker_hp": 32, "soldier_hp": 75, "speed": 1.2, "aggression": 0.85, "cohesion": 0.4, "armor": 2, "venom": 5, "queen_buff": 1.05, "panic_resist": 0.5, "portrait": "res://Assets/Art/fire_ant.png", "colony_stats": "res://Data/Colonies/fire_ant.tres"},
]

func get_current() -> Dictionary:
	return queens[current_index]

func advance() -> void:
	current_index = min(current_index + 1, queens.size() - 1)

func is_final() -> bool:
	return current_index >= queens.size() - 1
