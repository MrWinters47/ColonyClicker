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

@onready var perk_panel = $ElementPanel
@onready var perks_button = $PerksButton



# =============================================================================
# SPAWN SETTINGS
# =============================================================================
# How long the player must wait between spawn clicks
const SPAWN_DURATION: float = 1.0
var _spawning: bool = false

# Guaranteed ants per manual click — keep low so every ant feels earned
@export var base_spawn: int = 1

# Banks fractional bonus ants so small multiplier upgrades are never wasted
var _spawn_remainder: float = 0.0


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
	perks_button.pressed.connect(_on_perks_btn_pressed)

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
	var reward: int = base_spawn

	_spawn_remainder += base_spawn * GameManager.spawn_multiplier
	if _spawn_remainder >= 1.0:
		var bonus: int = int(_spawn_remainder)
		reward += bonus
		_spawn_remainder -= bonus

	# ─── Real colony grows — Main.gd threshold system handles visual spawning
	GameManager.ant_count += reward
	EventBus.ant_spawned.emit(null)

	spawn_progress.value  = 0
	spawn_button.disabled = false
	_spawning             = false
	_update_ant_label()
	play_sfx($Click)

	# ─── Real colony grows — Main.gd threshold system handles visual spawning
	GameManager.ant_count += reward
	EventBus.ant_spawned.emit(null)

	spawn_progress.value  = 0
	spawn_button.disabled = false
	_spawning             = false
	_update_ant_label()
	play_sfx($Click)

	# ─── ant_count is now handled inside register_ant() — remove the manual line
	EventBus.ant_spawned.emit(null)

	spawn_progress.value  = 0
	spawn_button.disabled = false
	_spawning             = false
	_update_ant_label()
	play_sfx($Click)


# Call this instead of $Click.play() every time you spawn
func play_sfx(player: AudioStreamPlayer2D) -> void:
	player.pitch_scale = randf_range(0.25, 1.15)
	player.play()
# =============================================================================
# LABEL UPDATES
# =============================================================================
func _on_sucrose_changed(amount: float) -> void:
	# ─── Show sucrose as clean integer — no decimals
	sucrose_label.text = "Sucrose: " + str(int(amount))
	$Sugar_fx.play()

func _update_ant_label() -> void:
	var colony = GameManager.active_colony
	var name   = colony.colony_name if colony else "Colony"
	ant_label.text = name + " — Colony: " + str(GameManager.ant_count) \
					+ " (" + str(GameManager.visual_ant_count) + " on screen)"

# =============================================================================
# UPGRADE EFFECTS — applied immediately when purchased
# =============================================================================
func _on_upgrade_purchased(id: String) -> void:
	_apply_upgrade(id)


func _apply_upgrade(id: String) -> void:
	match id:
		# ─── SPEED branch
		"faster_legs":
			# +10% speed on every live ant, hard cap 300
			for ant in get_tree().get_nodes_in_group("ants"):
				ant.speed = min(ant.speed * 1.10, 300.0)

		"sprinter_genes":
			# +5% speed and a higher cap unlocked late
			for ant in get_tree().get_nodes_in_group("ants"):
				ant.speed = min(ant.speed * 1.05, 350.0)

		# ─── SPAWN branch — reads/writes the same multiplier clicks and passive both use
		"faster_hatchery":
			GameManager.spawn_multiplier += 0.05

		"royal_pheromones":
			GameManager.spawn_multiplier += 0.10

		# ─── FORAGING branch
		"better_nose":
			for ant in get_tree().get_nodes_in_group("ants"):
				ant.food_awareness_radius *= 1.5

		"hawk_eyes":
			for ant in get_tree().get_nodes_in_group("ants"):
				ant.food_awareness_radius *= 1.25

		# ─── COMMAND branch
		"click_influence":
			GameManager.ant_click_influence += 1

		# ─── ONE-OFF
		"bigger_colony":
			GameManager.ant_count += 20
			EventBus.ant_spawned.emit(null)


var _perks_open: bool = false

func _on_perks_btn_pressed() -> void:
	if _perks_open:
		_perks_open = false
		perk_panel.close_panel()
		await get_tree().create_timer(1).timeout
		perk_panel.hide()
	else:
		upgrade_panel.hide()
		battle_panel.hide()
		perk_panel.show()
		perk_panel.open_panel()
		_perks_open = true
