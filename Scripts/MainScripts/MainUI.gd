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
@onready var perk_panel     = $ElementPanel
@onready var perks_button   = $PerksButton

# =============================================================================
# SPAWN SETTINGS
# =============================================================================
const SPAWN_DURATION: float = 1.0
var _spawning: bool = false
@export var base_spawn: int = 1
var _spawn_remainder: float = 0.0

# ─── Track perk panel state for the swoop animation
var _perks_open: bool = false

# =============================================================================
# READY
# =============================================================================
func _ready() -> void:
	EventBus.sucrose_changed.connect(_on_sucrose_changed)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	EventBus.colony_loaded.connect(func(_c): _update_ant_label())
	EventBus.ant_spawned.connect(func(_a): _update_ant_label())
	EventBus.ant_died.connect(func(_a): _update_ant_label())

	upgrade_btn.pressed.connect(_on_upgrade_btn_pressed)
	spawn_button.pressed.connect(_on_spawn_pressed)
	battle_button.pressed.connect(_on_battle_btn_pressed)
	perks_button.pressed.connect(_on_perks_btn_pressed)

	# ─── All panels closed at start
	upgrade_panel.hide()
	battle_panel.hide()
	perk_panel.hide()
	spawn_progress.value     = 0
	spawn_progress.max_value = 100
	sucrose_label.text       = "Sucrose: 0"
	_update_ant_label()

# =============================================================================
# PANEL MANAGEMENT — single source of truth
# =============================================================================
func _close_all_panels() -> void:
	# ─── Hide every panel before opening a new one — prevents stacking
	if upgrade_panel.visible:
		upgrade_panel.hide()
	if battle_panel.visible:
		battle_panel.hide()
	if _perks_open:
		_close_perks_immediate()

func _close_perks_immediate() -> void:
	# ─── Used when forcibly closing (e.g. opening another panel)
	_perks_open = false
	if perk_panel.has_method("close_panel"):
		perk_panel.close_panel()
	perk_panel.hide()

# =============================================================================
# PANEL TOGGLES
# =============================================================================
func _on_upgrade_btn_pressed() -> void:
	if upgrade_panel.visible:
		upgrade_panel.hide()
	else:
		_close_all_panels()
		upgrade_panel.show()

func _on_battle_btn_pressed() -> void:
	if battle_panel.visible:
		battle_panel.hide()
	else:
		_close_all_panels()
		battle_panel.show()

func _on_perks_btn_pressed() -> void:
	if _perks_open:
		_perks_open = false
		perk_panel.close_panel()
		await get_tree().create_timer(0.5).timeout
		perk_panel.hide()
	else:
		_close_all_panels()
		perk_panel.show()
		perk_panel.open_panel()
		_perks_open = true

# =============================================================================
# SPAWN BUTTON
# =============================================================================
func _on_spawn_pressed() -> void:
	if _spawning:
		return
	_spawning             = true
	spawn_button.disabled = true
	var tween = create_tween()
	tween.tween_property(spawn_progress, "value", 100.0, SPAWN_DURATION)
	tween.finished.connect(_on_spawn_complete)

func _on_spawn_complete() -> void:
	# ─── ONE clean spawn — was triplicated before, every fire stacked 3 spawns
	var reward: int = base_spawn

	_spawn_remainder += base_spawn * GameManager.spawn_multiplier
	if _spawn_remainder >= 1.0:
		var bonus: int = int(_spawn_remainder)
		reward += bonus
		_spawn_remainder -= bonus

	GameManager.ant_count += reward
	EventBus.ant_spawned.emit(null)

	spawn_progress.value  = 0
	spawn_button.disabled = false
	_spawning             = false
	_update_ant_label()
	play_sfx($Click)

func play_sfx(player: AudioStreamPlayer2D) -> void:
	player.pitch_scale = randf_range(0.85, 1.15)
	player.play()

# =============================================================================
# LABEL UPDATES
# =============================================================================
func _on_sucrose_changed(amount: float) -> void:
	sucrose_label.text = "Sucrose: " + str(int(amount))
	$Sugar_fx.play()

func _update_ant_label() -> void:
	var colony = GameManager.active_colony
	var name   = colony.colony_name if colony else "Colony"
	ant_label.text = name + " — Colony: " + str(GameManager.ant_count) \
					+ " (" + str(GameManager.visual_ant_count) + " on screen)"

# =============================================================================
# UPGRADE EFFECTS
# =============================================================================
func _on_upgrade_purchased(id: String) -> void:
	_apply_upgrade(id)

func _apply_upgrade(id: String) -> void:
	match id:
		"faster_legs":
			for ant in get_tree().get_nodes_in_group("ants"):
				ant.speed = min(ant.speed * 1.10, 300.0)
		"sprinter_genes":
			for ant in get_tree().get_nodes_in_group("ants"):
				ant.speed = min(ant.speed * 1.05, 350.0)
		"faster_hatchery":
			GameManager.spawn_multiplier += 0.05
		"royal_pheromones":
			GameManager.spawn_multiplier += 0.10
		"better_nose":
			for ant in get_tree().get_nodes_in_group("ants"):
				ant.food_awareness_radius *= 1.5
		"hawk_eyes":
			for ant in get_tree().get_nodes_in_group("ants"):
				ant.food_awareness_radius *= 1.25
		"click_influence":
			GameManager.ant_click_influence += 1
		"bigger_colony":
			GameManager.ant_count += 20
			EventBus.ant_spawned.emit(null)

# =============================================================================
# ANIMATION HOOKS — only fire if the buttons are still wired in the scene
# =============================================================================
func _on_battle_button_pressed() -> void:
	# ─── If you've wired an AnimationPlayer for fullscreen battle, this plays it
	if has_node("AnimationPlayer"):
		$AnimationPlayer.play("fullscreen_for_battle")

func _on_return_ui_button_pressed() -> void:
	if has_node("AnimationPlayer"):
		$AnimationPlayer.play_backwards("fullscreen_for_battle")
