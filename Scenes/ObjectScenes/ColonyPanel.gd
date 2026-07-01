extends VBoxContainer
# =============================================================================
# MY COLONY PANEL
# A live window into the nest. READS game state only — owns nothing, changes
# nothing. Builds all its rows once, then refreshes itself 4x/sec while visible.
# Attach this to a VBoxContainer sitting inside your "MY COLONY" plaque.
# =============================================================================

const REFRESH_INTERVAL: float = 0.25
var _refresh_timer: float = 0.0

# ─── Live refs, filled in _build_ui()
var _name_lbl: Label
var _species_lbl: Label
var _threat_lbl: Label
var _morale_bar: ProgressBar
var _total_lbl: Label
var _surface_lbl: Label
var _under_lbl: Label
var _activity_lbl: Label
var _aggr_bar: ProgressBar
var _cohe_bar: ProgressBar
var _nerve_bar: ProgressBar
var _combat_lbl: Label

func _ready() -> void:
	add_theme_constant_override("separation", 4)
	_build_ui()
	_refresh()

func _process(delta: float) -> void:
	# ─── Don't burn cycles when the plaque is closed
	if not is_visible_in_tree():
		return
	_refresh_timer += delta
	if _refresh_timer >= REFRESH_INTERVAL:
		_refresh_timer = 0.0
		_refresh()

# =============================================================================
# BUILD — make every row exactly once
# =============================================================================
func _build_ui() -> void:
	_name_lbl    = _make_label(22, Color.WHITE)
	_species_lbl = _make_label(13, Color(0.85, 0.80, 0.70))

	_section("STATUS")
	_threat_lbl = _make_label(16, Color.WHITE)
	_morale_bar = _make_bar("Morale", 100.0)

	_section("POPULATION")
	_total_lbl    = _make_label(14, Color(0.95, 0.95, 0.95))
	_surface_lbl  = _make_label(14, Color(0.95, 0.95, 0.95))
	_under_lbl    = _make_label(14, Color(0.95, 0.95, 0.95))
	_activity_lbl = _make_label(13, Color(0.80, 0.80, 0.80))

	_section("TRAITS")
	_aggr_bar   = _make_bar("Aggression", 1.0)
	_cohe_bar   = _make_bar("Cohesion", 1.0)
	_nerve_bar  = _make_bar("Nerve", 1.0)
	_combat_lbl = _make_label(13, Color(0.80, 0.80, 0.80))

# ─── A plain text row
func _make_label(size: int, color: Color) -> Label:
	var l = Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	add_child(l)
	return l

# ─── A titled progress bar (label on the left, bar fills the rest)
func _make_bar(title: String, max_value: float) -> ProgressBar:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)

	var lbl = Label.new()
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.80, 0.70))
	lbl.custom_minimum_size = Vector2(95, 0)
	lbl.text = title
	row.add_child(lbl)

	var bar = ProgressBar.new()
	bar.max_value = max_value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 16)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bar)
	return bar

# ─── A small section header
func _section(title: String) -> void:
	var l = Label.new()
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color(0.70, 0.60, 0.40))
	l.text = title
	add_child(l)

# =============================================================================
# REFRESH — pull live numbers every tick
# =============================================================================
func _refresh() -> void:
	var c = GameManager.active_colony

	# ─── Identity
	if c:
		_name_lbl.text = c.colony_name if c.colony_name != "" else "Your Colony"
		var sp = c.species if c.species != "" else "Unknown ant"
		_species_lbl.text = sp + "  ·  Gen " + str(EnemyColonies.current_index + 1) \
			+ "/" + str(EnemyColonies.queens.size())
	else:
		_name_lbl.text    = "Your Colony"
		_species_lbl.text = "Awaiting queen…"

	# ─── Threat badge — colour comes straight from GameManager
	_threat_lbl.text = "Threat:  " + GameManager.get_threat_label()
	_threat_lbl.add_theme_color_override("font_color", GameManager.get_threat_color())

	# ─── Morale
	_morale_bar.value = GameManager.colony_morale

	# ─── Population — surface vs underground falls out of your visual/real split
	var total   = GameManager.ant_count
	var surface = GameManager.visual_ant_count
	var under   = max(0, total - surface)
	_total_lbl.text   = "Colony size:  " + _fmt(total)
	_surface_lbl.text = "On surface:   " + _fmt(surface)
	_under_lbl.text   = "Underground:  " + _fmt(under)

	# ─── Live activity split (cheap loop — only runs while the panel is open)
	var foraging := 0
	var returning := 0
	for ant in get_tree().get_nodes_in_group("ants"):
		if not ant is BaseAnt:
			continue
		match ant.state:
			BaseAnt.State.FORAGING, BaseAnt.State.EATING:
				foraging += 1
			BaseAnt.State.RETURNING, BaseAnt.State.DEPOSITING:
				returning += 1
	_activity_lbl.text = "Foraging: " + str(foraging) + "   Returning: " + str(returning)

	# ─── Traits — the 0–1 stats make natural bars
	if c:
		_aggr_bar.value  = c.aggression
		_cohe_bar.value  = c.cohesion
		_nerve_bar.value = c.panic_resist
		_combat_lbl.text = "Atk " + str(int(c.base_attack)) \
			+ "    Def " + str(int(c.base_defense)) \
			+ "    Spd " + ("%.1f" % c.base_speed)
	else:
		_aggr_bar.value  = 0
		_cohe_bar.value  = 0
		_nerve_bar.value = 0
		_combat_lbl.text = ""

# ─── 1234 → "1,234"
func _fmt(n: int) -> String:
	var s = str(n)
	var out = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out
