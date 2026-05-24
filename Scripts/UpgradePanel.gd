extends PanelContainer

@onready var upgrade_list = $VBoxContainer/ScrollContainer/UpgradeList
@onready var close_button = $VBoxContainer/CloseButton

const UpgradeCard = preload("res://Scenes/ObjectScenes/UpgradeCard.tscn")

func _ready() -> void:
	close_button.pressed.connect(func(): hide())
	_populate()

func _populate() -> void:
	_add_card("faster_legs",   "Faster Legs",   "Ants move 10% faster",     1.0,  10)
	_add_card("bigger_colony", "Bigger Colony", "Spawn 5 more ants",        100.0, 5)
	_add_card("better_nose",   "Better Nose",   "Ants detect food further", 75.0,  10)
	_add_card("click_influence", "Rally More Ants", "Click rallies more ants", 150.0, 9)


func _add_card(id: String, name: String, desc: String, cost: float, max_lvl: int) -> void:
	var card = UpgradeCard.instantiate()
	upgrade_list.add_child(card)
	card.setup(id, name, desc, cost, max_lvl)
