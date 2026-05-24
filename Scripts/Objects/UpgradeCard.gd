extends PanelContainer

@onready var upgrade_name = $HBoxContainer/VBoxContainer/UpgradeName
@onready var upgrade_desc = $HBoxContainer/VBoxContainer/UpgradeDesc
@onready var upgrade_cost = $HBoxContainer/VBoxContainer2/UpgradeCost
@onready var buy_button = $HBoxContainer/VBoxContainer2/BuyButton
@onready var progress_bar = $HBoxContainer/VBoxContainer2/ProgressBar

var upgrade_id: String = ""
var cost: float = 50.0
var current_level: int = 0
var max_level: int = 10

func setup(id: String, display_name: String, desc: String, base_cost: float, max_lvl: int = 10) -> void:
	upgrade_id = id
	cost = base_cost
	max_level = max_lvl
	upgrade_name.text = display_name
	upgrade_desc.text = desc
	progress_bar.max_value = max_level
	progress_bar.value = 0
	_update_ui()
	buy_button.pressed.connect(_on_buy_pressed)
	EventBus.sucrose_changed.connect(_on_sucrose_changed)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)

func _update_ui() -> void:
	upgrade_cost.text = "Cost: " + str(cost)
	progress_bar.value = current_level
	if current_level >= max_level:
		buy_button.text = "MAX"
		buy_button.disabled = true
	else:
		buy_button.text = "Buy"

func _on_sucrose_changed(amount: float) -> void:
	if current_level < max_level:
		buy_button.disabled = amount < cost

func _on_upgrade_purchased(id: String) -> void:
	if id == upgrade_id:
		current_level += 1
		_update_ui()

func _on_buy_pressed() -> void:
	if GameManager.spend_sucrose(cost):
		EventBus.upgrade_purchased.emit(upgrade_id)
