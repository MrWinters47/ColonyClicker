extends PanelContainer

@onready var player_name    = $PlayerSide/HBoxContainer/VBoxContainer/PlayerName
@onready var player_bar     = $PlayerSide/HBoxContainer/VBoxContainer/PlayerBar
@onready var vs_label       = $PlayerSide/HBoxContainer/VsLabel
@onready var enemy_portrait = $PlayerSide/HBoxContainer/VBoxContainer2/EnemyPortrait
@onready var enemy_name     = $PlayerSide/HBoxContainer/VBoxContainer2/EnemyName
@onready var enemy_bar      = $PlayerSide/HBoxContainer/VBoxContainer2/EnemyBar
@onready var odds_bar       = $PlayerSide/OddsBar
@onready var battle_log     = $PlayerSide/RichTextLabel
@onready var fight_button   = $PlayerSide/FightButton
@onready var close_button   = $PlayerSide/CloseButton

var _signals_connected: bool = false

# ─── Results overlay — built in code, covers the whole battle panel
var results_overlay: PanelContainer
var results_title:   Label
var results_stats:   Label
var results_perk:    Label
var prestige_button: Button
var continue_button: Button

func _ready() -> void:
	fight_button.pressed.connect(_on_fight_pressed)
	close_button.pressed.connect(func(): hide())
	close_button.hide()
	_connect_battle_signals()
	_build_results_overlay()
	_show_enemy_info()

func _connect_battle_signals() -> void:
	# ─── Connect ONCE in _ready, never per-fight or they stack up
	if _signals_connected:
		return
	BattleSystem.battle_started.connect(_on_battle_started)
	BattleSystem.tick_resolved.connect(_on_tick_resolved)
	BattleSystem.narrative_line.connect(_on_narrative_line)
	BattleSystem.battle_ended.connect(_on_battle_ended)
	_signals_connected = true

func _show_enemy_info() -> void:
	var enemy = EnemyColonies.get_current()
	var c     = GameManager.active_colony
	player_name.text = c.colony_name if c else "Your Colony"
	enemy_name.text  = enemy.name
	vs_label.text    = "VS"

	var p_force = int(max(GameManager.ant_count, 5) * BattleSystem.ANT_FORCE_MULT)
	var e_force = enemy.workers + enemy.soldiers
	player_bar.max_value = p_force
	player_bar.value     = p_force
	enemy_bar.max_value  = e_force
	enemy_bar.value      = e_force
	odds_bar.max_value   = p_force + e_force
	odds_bar.value       = p_force

	var portrait_tex = load(enemy.portrait) if ResourceLoader.exists(enemy.portrait) else null
	if portrait_tex:
		enemy_portrait.texture = portrait_tex

func _on_fight_pressed() -> void:
	fight_button.disabled = true
	close_button.hide()
	results_overlay.hide()
	battle_log.text = ""
	battle_log.append_text("[center][b]⚔ THE BATTLE BEGINS ⚔[/b][/center]")

	var enemy = EnemyColonies.get_current()
	battle_log.append_text("\nYour colony charges the " + enemy.name + " colony!")

	BattleSystem.start_battle(enemy)

# =============================================================================
# BATTLE SIGNAL HANDLERS
# =============================================================================
func _on_battle_started(player: Dictionary, enemy: Dictionary) -> void:
	var p_max = player.workers + player.soldiers
	var e_max = enemy.workers + enemy.soldiers
	player_bar.max_value = p_max
	player_bar.value     = p_max
	enemy_bar.max_value  = e_max
	enemy_bar.value      = e_max
	odds_bar.max_value   = p_max + e_max
	odds_bar.value       = p_max

func _on_tick_resolved(snapshot: Dictionary) -> void:
	var p_total = snapshot.player.workers + snapshot.player.soldiers
	var e_total = snapshot.enemy.workers + snapshot.enemy.soldiers
	player_bar.value = p_total
	enemy_bar.value  = e_total
	odds_bar.value   = p_total

func _on_narrative_line(text: String) -> void:
	battle_log.append_text("\n" + text)

func _on_battle_ended(result: Dictionary) -> void:
	close_button.show()
	fight_button.disabled = false
	if result.winner == "player":
		_show_victory(result)
	else:
		_show_defeat(result)

# =============================================================================
# RESULTS — victory unlocks the perk, prestige waits for the button
# =============================================================================
func _show_victory(result: Dictionary) -> void:
	# ─── The queen you JUST beat — do NOT advance yet, the button does that
	var queen = EnemyColonies.get_current()

	# ─── Her perk is yours — unlocked, not auto-equipped. Player chooses.
	PerkManager.unlock_perk_by_id(queen.get("perk_id", ""))

	results_title.text = "★ VICTORY ★"
	results_title.add_theme_color_override("font_color", Color(0.35, 0.95, 0.45))
	results_stats.text = "Won by %s\nYour losses: %d%%   Enemy losses: %d%%" % [
		result.method, int(result.player_loss * 100), int(result.enemy_loss * 100)
	]

	var perk = PerkManager.perk_registry.get(queen.get("perk_id", ""), null)
	if perk:
		results_perk.text = "✦ NEW PERK UNLOCKED ✦\n%s — %s" % [perk.display_name, perk.description]
	else:
		results_perk.text = ""

	prestige_button.text = "👑 BECOME THE %s QUEEN" % queen.name.to_upper()
	prestige_button.show()
	results_overlay.show()

func _show_defeat(result: Dictionary) -> void:
	results_title.text = "DEFEAT"
	results_title.add_theme_color_override("font_color", Color(0.95, 0.3, 0.3))
	results_stats.text = "Your losses: %d%%   Enemy losses: %d%%\nGrow the colony and try again." % [
		int(result.player_loss * 100), int(result.enemy_loss * 100)
	]
	results_perk.text = ""
	prestige_button.hide()
	results_overlay.show()

func _on_prestige_pressed() -> void:
	var queen = EnemyColonies.get_current()
	# ─── Transform into the DEFEATED queen — then move the ladder forward
	var new_stats = EnemyColonies.build_colony_stats(queen)
	GameManager.prestige(new_stats)
	EnemyColonies.advance()
	results_overlay.hide()
	battle_log.text = ""
	battle_log.append_text("[center]A new reign begins — %s.[/center]" % queen.colony_name)
	_show_enemy_info()

# =============================================================================
# OVERLAY BUILDER
# =============================================================================
func _build_results_overlay() -> void:
	results_overlay = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.04, 0.07, 0.97)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(28)
	results_overlay.add_theme_stylebox_override("panel", sb)
	results_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	results_overlay.visible = false
	add_child(results_overlay)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	results_overlay.add_child(box)

	results_title = Label.new()
	results_title.add_theme_font_size_override("font_size", 42)
	results_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(results_title)

	results_stats = Label.new()
	results_stats.add_theme_font_size_override("font_size", 24)
	results_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(results_stats)

	results_perk = Label.new()
	results_perk.add_theme_font_size_override("font_size", 24)
	results_perk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	results_perk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	results_perk.add_theme_color_override("font_color", Color(1.0, 0.78, 0.2))
	box.add_child(results_perk)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	prestige_button = Button.new()
	prestige_button.add_theme_font_size_override("font_size", 28)
	prestige_button.pressed.connect(_on_prestige_pressed)
	box.add_child(prestige_button)

	continue_button = Button.new()
	continue_button.text = "CONTINUE"
	continue_button.add_theme_font_size_override("font_size", 22)
	continue_button.pressed.connect(func(): results_overlay.hide())
	box.add_child(continue_button)

# =============================================================================
# SPEED BUTTONS
# =============================================================================
func _on_speed_1x_pressed() -> void: BattleSystem.set_speed(1.0)
func _on_speed_2x_pressed() -> void: BattleSystem.set_speed(2.0)
func _on_speed_4x_pressed() -> void: BattleSystem.set_speed(4.0)
