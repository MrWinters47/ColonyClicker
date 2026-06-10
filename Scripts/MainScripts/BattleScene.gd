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

func _ready() -> void:
	fight_button.pressed.connect(_on_fight_pressed)
	close_button.pressed.connect(func(): hide())
	close_button.hide()
	_connect_battle_signals()
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
	
	# ─── Use BattleSystem's multiplier so preview bars match the real fight
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
	battle_log.text       = ""
	battle_log.append_text("[center][b]⚔ THE BATTLE BEGINS ⚔[/b][/center]")
	
	var enemy = EnemyColonies.get_current()
	battle_log.append_text("\nYour colony charges the " + enemy.name + " colony!")
	
	BattleSystem.start_battle(enemy)

# =============================================================================
# BATTLE SIGNAL HANDLERS — react to ticks in real time
# =============================================================================
func _on_battle_started(player: Dictionary, enemy: Dictionary) -> void:
	# ─── Lock max bars to the actual battle state (source of truth)
	var p_max = player.workers + player.soldiers
	var e_max = enemy.workers + enemy.soldiers
	player_bar.max_value = p_max
	player_bar.value     = p_max
	enemy_bar.max_value  = e_max
	enemy_bar.value      = e_max
	odds_bar.max_value   = p_max + e_max
	odds_bar.value       = p_max

func _on_tick_resolved(snapshot: Dictionary) -> void:
	# ─── Fires every tick_interval (~8/sec at 1x, ~32/sec at 4x) — smooth drain
	var p_total = snapshot.player.workers + snapshot.player.soldiers
	var e_total = snapshot.enemy.workers + snapshot.enemy.soldiers
	player_bar.value = p_total
	enemy_bar.value  = e_total
	odds_bar.value   = p_total

func _on_narrative_line(text: String) -> void:
	battle_log.append_text("\n" + text)

func _on_battle_ended(result: Dictionary) -> void:
	if result.winner == "player":
		EnemyColonies.advance()
		var next = EnemyColonies.get_current()
		if next.has("colony_stats") and ResourceLoader.exists(next.colony_stats):
			var new_stats = load(next.colony_stats)
			GameManager.prestige(new_stats)
		_show_victory_screen(EnemyColonies.queens[EnemyColonies.current_index - 1].name)
		# ─── Refresh preview for the next enemy on the ladder
		_show_enemy_info()
	
	close_button.show()
	fight_button.disabled = false

func _show_victory_screen(defeated_name: String) -> void:
	battle_log.append_text("\n\n[center][b]★ YOU ARE NOW " + defeated_name.to_upper() + " ★[/b][/center]")
	battle_log.append_text("\n[center]Upgrades reset. Colony transformed.[/center]")
	battle_log.append_text("\n[center]Perks carried forward.[/center]")
	battle_log.append_text("\n[center]The colony marches on.[/center]")

# =============================================================================
# OPTIONAL: speed buttons — wire these to 3 buttons in the scene tree
# =============================================================================
func _on_speed_1x_pressed() -> void: BattleSystem.set_speed(1.0)
func _on_speed_2x_pressed() -> void: BattleSystem.set_speed(2.0)
func _on_speed_4x_pressed() -> void: BattleSystem.set_speed(4.0)
