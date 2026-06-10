extends PanelContainer

# ─── UI nodes
@onready var upgrade_name = $HBoxContainer/VBoxContainer/UpgradeName
@onready var upgrade_desc = $HBoxContainer/VBoxContainer/UpgradeDesc
@onready var upgrade_cost = $HBoxContainer/VBoxContainer2/UpgradeCost
@onready var buy_button   = $HBoxContainer/VBoxContainer2/BuyButton
@onready var progress_bar = $HBoxContainer/VBoxContainer2/ProgressBar

# ─── Which upgrade this card represents — set once, everything else is read live
var upgrade_id: String = ""

# ─── Wire the card to an id; UpgradeManager is the source of truth from here on
func setup(id: String) -> void:
	upgrade_id = id
	var upgrade = UpgradeManager.get_def(id)
	if not upgrade:
		push_error("UpgradeCard: no def registered for id " + id)
		return
	upgrade_name.text      = upgrade.display_name
	upgrade_desc.text      = upgrade.description
	progress_bar.max_value = upgrade.max_level
	buy_button.pressed.connect(_on_buy_pressed)
	EventBus.sucrose_changed.connect(func(_amount): _refresh())
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	_refresh()

# ─── Repaint the card based on the live state of the upgrade + player
func _refresh() -> void:
	var upgrade = UpgradeManager.get_def(upgrade_id)
	var level   = UpgradeManager.get_level(upgrade_id)
	progress_bar.value = level

	# ─── Locked — prereq not yet met. Visible but greyed out (Egg Inc style)
	if not UpgradeManager.is_unlocked(upgrade_id):
		var prereq      = UpgradeManager.get_def(upgrade.prerequisite_id)
		var prereq_name = prereq.display_name if prereq else upgrade.prerequisite_id
		upgrade_cost.text   = "Locked — needs " + prereq_name + " Lv " + str(upgrade.prerequisite_level)
		buy_button.text     = "LOCKED"
		buy_button.disabled = true
		modulate            = Color(0.55, 0.55, 0.55, 1.0)
		return

	# ─── Maxed — fully purchased
	if level >= upgrade.max_level:
		upgrade_cost.text   = "MAXED"
		buy_button.text     = "MAX"
		buy_button.disabled = true
		modulate            = Color(1, 1, 1, 1)
		return

	# ─── Buyable — show live scaled cost
	var cost = UpgradeManager.get_cost(upgrade_id)
	upgrade_cost.text   = "Cost: " + str(int(cost))
	buy_button.text     = "Buy"
	buy_button.disabled = GameManager.sucrose < cost
	modulate            = Color(1, 1, 1, 1)

# ─── Any purchase anywhere might have unlocked us — refresh
func _on_upgrade_purchased(_id: String) -> void:
	_refresh()

# ─── Route through UpgradeManager. No direct spend_sucrose here.
func _on_buy_pressed() -> void:
	UpgradeManager.purchase(upgrade_id)
