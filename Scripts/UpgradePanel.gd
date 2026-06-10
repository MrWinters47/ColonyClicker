extends PanelContainer

@onready var upgrade_list = $VBoxContainer/ScrollContainer/UpgradeList
@onready var close_button = $VBoxContainer/CloseButton

const UpgradeCard = preload("res://Scenes/ObjectScenes/UpgradeCard.tscn")

func _ready() -> void:
	close_button.pressed.connect(func(): hide())
	_register_upgrades()
	_populate_cards()

# =============================================================================
# THE UPGRADE TREE — add, remove, or retune entries here
# Args: id, display name, description, base cost, cost multiplier,
#       max levels, prerequisite id (or ""), prerequisite level
# =============================================================================
func _register_upgrades() -> void:
	# ─── SPEED branch
	_register("faster_legs",      "Faster Legs",      "Ants move 10% faster",          50.0,   1.5, 10, "",                0)
	_register("sprinter_genes",   "Sprinter Genes",   "+5% speed, raises the cap",     1500.0, 2.0, 5,  "faster_legs",     10)

	# ─── SPAWN branch (all feed the same GameManager.spawn_multiplier)
	_register("faster_hatchery",  "Faster Hatchery",  "+0.05 spawn boost per level",   30.0,   1.4, 20, "",                0)
	_register("royal_pheromones", "Royal Pheromones", "+0.10 spawn boost per level",   1000.0, 1.8, 10, "faster_hatchery", 20)

	# ─── FORAGING branch
	_register("better_nose",      "Better Nose",      "Ants detect food 50% further",  75.0,   1.5, 10, "",                0)
	_register("hawk_eyes",        "Hawk Eyes",        "+25% food detection radius",    2000.0, 2.0, 5,  "better_nose",     10)

	# ─── COMMAND branch
	_register("click_influence",  "Click Influence",  "+1 ant follows your rally",     100.0,  1.6, 10, "",                0)

	# ─── ONE-OFF
	_register("bigger_colony",    "Bigger Colony",    "Instantly spawn 20 ants",       200.0,  1.7, 10, "",                0)

# ─── Builds an UpgradeDef in code so you don't have to make a .tres per upgrade
func _register(id: String, name: String, desc: String, cost: float, mult: float,
		max_lvl: int, prereq_id: String, prereq_lvl: int) -> void:
	var upgrade = UpgradeDef.new()
	upgrade.id                 = id
	upgrade.display_name       = name
	upgrade.description        = desc
	upgrade.base_cost          = cost
	upgrade.cost_multiplier    = mult
	upgrade.max_level          = max_lvl
	upgrade.prerequisite_id    = prereq_id
	upgrade.prerequisite_level = prereq_lvl
	UpgradeManager.register_def(upgrade)

# ─── Spawn one card per registered upgrade in registration order
func _populate_cards() -> void:
	for upgrade in UpgradeManager.get_all_defs():
		var card = UpgradeCard.instantiate()
		upgrade_list.add_child(card)
		card.setup(upgrade.id)
