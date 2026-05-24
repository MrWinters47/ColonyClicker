extends Resource
class_name ColonyStats

# Identity
@export var colony_name: String = ""
@export var species: String = ""

# Base combat stats
@export var base_health: float = 100.0
@export var base_attack: float = 10.0
@export var base_defense: float = 5.0
@export var base_speed: float = 1.0
@export var base_forage_rate: float = 1.0

# Battle stats
@export var venom: float = 2.0
@export var cohesion: float = 0.5
@export var aggression: float = 0.6
@export var panic_resist: float = 0.3
@export var queen_buff: float = 1.10

# Population
@export var max_workers: int = 20
@export var max_soldiers: int = 10

# Special ability (unique per species)
@export var ability_id: String = ""
