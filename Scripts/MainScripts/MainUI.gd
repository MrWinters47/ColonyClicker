extends CanvasLayer

# =============================================================================
# NODE REFERENCES
# =============================================================================
@onready var sucrose_label  = $TopBar/Control/SucroseLabel
@onready var ant_label      = $TopBar/Control/AntsLabel
@onready var upgrade_btn    = $UpgradeButton
@onready var upgrade_panel  = $UpgradePanel
@onready var spawn_button   = $SpawnButton
@onready var spawn_progress = $SpawnProgress
@onready var battle_panel   = $BattleScene
@onready var battle_button  = $BattleButton

# =============================================================================
# SPAWN SETTINGS
# =============================================================================
# How long the player must wait between spawn clicks
const SPAWN_DURATION: float = 2.0
var _spawning: bool = false

# =============================================================================
# READY — wire up all signals and set initial state
# =============================================================================
func _ready() -> void:
	# ─── Economy signals
	EventBus.sucrose_changed.connect(_on_sucrose_changed)

	# ─── Colony signals — update label whenever colony changes
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	EventBus.colony_loaded.connect(func(_c): _update_ant_label())
	EventBus.ant_spawned.connect(func(_a): _update_ant_label())
	EventBus.ant_died.connect(func(_a): _update_ant_label())

	# ─── Button connections
	upgrade_btn.pressed.connect(_on_upgrade_btn_pressed)
	spawn_button.pressed.connect(_on_spawn_pressed)
	battle_button.pressed.connect(_on_battle_btn_pressed)

	# ─── Initial UI state
	upgrade_panel.hide()
	battle_panel.hide()
	spawn_progress.value     = 0
	spawn_progress.max_value = 100
	sucrose_label.text       = "Sucrose: 0"
	_update_ant_label()

# =============================================================================
# PANEL TOGGLES
# =============================================================================
func _on_upgrade_btn_pressed() -> void:
	# ─── Toggle upgrade panel — closes battle if it was open
	if upgrade_panel.visible:
		upgrade_panel.hide()
	else:
		battle_panel.hide()
		upgrade_panel.show()

func _on_battle_btn_pressed() -> void:
	# ─── Toggle battle panel — closes upgrades if they were open
	if battle_panel.visible:
		battle_panel.hide()
	else:
		upgrade_panel.hide()
		battle_panel.show()

# =============================================================================
# SPAWN BUTTON — 2 second hatch timer, reward scales with colony size
# =============================================================================
func _on_spawn_pressed() -> void:
	# ─── Prevent double-clicking during hatch
	if _spawning:
		return

	_spawning             = true
	spawn_button.disabled = true

	# ─── Animate progress bar over SPAWN_DURATION then fire completion
	var tween = create_tween()
	tween.tween_property(spawn_progress, "value", 100.0, SPAWN_DURATION)
	tween.finished.connect(_on_spawn_complete)

func _on_spawn_complete() -> void:
	# ─── Reward scales up as colony grows — clicking feels more powerful late game
	var count  = GameManager.ant_count
	var reward = 1

	if count >= 1000:  reward = 50
	elif count >= 500: reward = 20
	elif count >= 100: reward = 8
	elif count >= 50:  reward = 3

	GameManager.ant_count += reward
	EventBus.ant_spawned.emit(null)

	# ─── Reset spawn button ready for next click
	spawn_progress.value  = 0
	spawn_button.disabled = false
	_spawning             = false
	_update_ant_label()

# =============================================================================
# LABEL UPDATES
# =============================================================================
func _on_sucrose_changed(amount: float) -> void:
	# ─── Show sucrose as clean integer — no decimals
	sucrose_label.text = "Sucrose: " + str(int(amount))

func _update_ant_label() -> void:
	# ─── Show real colony count (not just visual ants on screen)
	var colony     = GameManager.active_colony
	var name       = colony.colony_name if colony else "Colony"
	ant_label.text = name + " — Colony: " + str(GameManager.ant_count)

# =============================================================================
# UPGRADE EFFECTS — applied immediately when purchased
# =============================================================================
func _on_upgrade_purchased(id: String) -> void:
	_apply_upgrade(id)

func _apply_upgrade(id: String) -> void:
	match id:
		"faster_legs":
			# ─── Boost speed on all live ants, capped at 300
			for ant in get_tree().get_nodes_in_group("ants"):
				ant.speed = min(ant.speed * 1.10, 300.0)

		"bigger_colony":
			# ─── Adds directly to real colony count, not visual
			GameManager.ant_count += 20
			EventBus.ant_spawned.emit(null)

		"better_nose":
			# ─── Increase food awareness radius on all live ants
			for ant in get_tree().get_nodes_in_group("ants"):
				ant.food_awareness_radius *= 1.5

		"click_influence":
			# ─── Each level lets rally clicks command one more ant
			GameManager.ant_click_influence += 1
