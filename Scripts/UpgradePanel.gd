extends PanelContainer

# =============================================================================
# QUEEN ACCENTS — themed per species. active_colony.species is set by
# EnemyColonies.build_colony_stats(), so this auto-switches on prestige.
# Anything not listed falls back to amber (Carpenter start).
# =============================================================================
const DEFAULT_ACCENT := Color(1.00, 0.60, 0.20)
const QUEEN_ACCENTS := {
	"Fire Ant":         Color(1.00, 0.47, 0.20),
	"Argentine Ant":    Color(0.85, 0.65, 0.45),
	"Pavement Ant":     Color(0.66, 0.66, 0.70),
	"Bullet Ant":       Color(1.00, 0.20, 0.00),
	"Leafcutter Ant":   Color(0.50, 1.00, 0.60),
	"Army Ant":         Color(0.70, 0.14, 0.00),
	"Weaver Ant":       Color(0.85, 1.00, 0.40),
	"Driver Ant":       Color(0.50, 0.13, 0.13),
	"Jack Jumper":      Color(1.00, 0.84, 0.00),
	"Trap-jaw Ant":     Color(1.00, 0.60, 0.20),
	"Bulldog Ant":      Color(1.00, 0.31, 0.31),
	"Giant Forest Ant": Color(1.00, 0.84, 0.00),
}

# =============================================================================
# PALETTE
# =============================================================================
const COL_PANEL  := Color(0.10, 0.11, 0.13)
const COL_CARD   := Color(0.15, 0.16, 0.19)
const COL_TEXT   := Color(0.92, 0.93, 0.96)
const COL_DIM    := Color(0.92, 0.93, 0.96, 0.50)
const COL_LOCKED := Color(0.50, 0.52, 0.56)

# =============================================================================
# BRANCH GROUPING — display order + section headers.
# IDs must match what _register_upgrades registers below.
# =============================================================================
const BRANCHES := [
	{"name": "SPEED",    "ids": ["faster_legs", "sprinter_genes"]},
	{"name": "SPAWN",    "ids": ["faster_hatchery", "royal_pheromones"]},
	{"name": "FORAGING", "ids": ["better_nose", "hawk_eyes"]},
	{"name": "COMMAND",  "ids": ["click_influence", "bigger_colony"]},
]

# =============================================================================
# STATE
# =============================================================================
var _registered: bool = false
var _cards: Array = []          # each: {id, root, sb, name, desc, cost, buy, bar}
var _sucrose_label: Label = null

# =============================================================================
# READY
# =============================================================================
func _ready() -> void:
	if not _registered:
		_register_upgrades()
		_registered = true
	_build_ui()
	EventBus.sucrose_changed.connect(func(_a): _on_sucrose_changed())
	EventBus.upgrade_purchased.connect(func(_id): _refresh_all())
	EventBus.colony_loaded.connect(func(_c): _build_ui())   # re-theme on prestige

# =============================================================================
# ACCENT
# =============================================================================
func _accent() -> Color:
	var c = GameManager.active_colony
	if c and "species" in c and QUEEN_ACCENTS.has(c.species):
		return QUEEN_ACCENTS[c.species]
	return DEFAULT_ACCENT

# =============================================================================
# UI BUILD
# =============================================================================
func _build_ui() -> void:
	for child in get_children():
		child.queue_free()
	_cards.clear()

	var accent = _accent()

	# ─── Panel background
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PANEL
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(0)
	add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	root.add_child(_build_header(accent))
	root.add_child(_build_scroll(accent))

# ─── Header: title + live sucrose + close
func _build_header(accent: Color) -> VBoxContainer:
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 4)

	var row := HBoxContainer.new()
	head.add_child(row)

	var title := Label.new()
	title.text = "UPGRADES"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", COL_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)

	_sucrose_label = Label.new()
	_sucrose_label.add_theme_font_size_override("font_size", 20)
	_sucrose_label.add_theme_color_override("font_color", accent)
	_sucrose_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_update_sucrose_text()
	row.add_child(_sucrose_label)

	var close := Button.new()
	close.text = "✕"
	close.add_theme_font_size_override("font_size", 20)
	close.pressed.connect(func(): hide())
	row.add_child(close)

	# ─── Accent underline
	var underline := ColorRect.new()
	underline.color = accent
	underline.custom_minimum_size.y = 3
	head.add_child(underline)

	return head

# ─── Scrollable list of grouped sections
func _build_scroll(accent: Color) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 14)
	scroll.add_child(list)

	for branch in BRANCHES:
		list.add_child(_make_section_header(branch.name, accent))
		for id in branch.ids:
			if UpgradeManager.get_def(id):
				var card = _build_card(id, accent)
				list.add_child(card.root)
				_cards.append(card)

	_refresh_all()
	return scroll

func _make_section_header(text: String, accent: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", accent)
	return l

# =============================================================================
# CARD — built in code, refreshed in place (no rebuild on sucrose ticks)
# =============================================================================
func _build_card(id: String, accent: Color) -> Dictionary:
	var upgrade = UpgradeManager.get_def(id)

	var root := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_CARD
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(14)
	root.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	root.add_child(hbox)

	# Left — name + description + level bar
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 4)
	hbox.add_child(left)

	var name_label := Label.new()
	name_label.text = upgrade.display_name
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", COL_TEXT)
	left.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = upgrade.description
	desc_label.add_theme_font_size_override("font_size", 15)
	desc_label.add_theme_color_override("font_color", COL_DIM)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(desc_label)

	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 6
	bar.max_value = upgrade.max_level
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0, 0, 0, 0.35)
	bar_bg.set_corner_radius_all(3)
	var bar_fg := StyleBoxFlat.new()
	bar_fg.bg_color = accent
	bar_fg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bar_bg)
	bar.add_theme_stylebox_override("fill", bar_fg)
	left.add_child(bar)

	# Right — cost + buy
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.custom_minimum_size.x = 110
	hbox.add_child(right)

	var cost_label := Label.new()
	cost_label.add_theme_font_size_override("font_size", 15)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(cost_label)

	var buy := Button.new()
	buy.add_theme_font_size_override("font_size", 18)
	buy.pressed.connect(func(): UpgradeManager.purchase(id))
	right.add_child(buy)

	return {
		"id": id, "root": root, "sb": sb,
		"name": name_label, "desc": desc_label,
		"cost": cost_label, "buy": buy, "bar": bar,
	}

# =============================================================================
# REFRESH
# =============================================================================
func _refresh_all() -> void:
	for card in _cards:
		_refresh_card(card)
	_update_sucrose_text()

func _refresh_card(card: Dictionary) -> void:
	var id      = card.id
	var upgrade = UpgradeManager.get_def(id)
	var level   = UpgradeManager.get_level(id)
	var accent  = _accent()
	card.bar.value = level

	# ─── LOCKED
	if not UpgradeManager.is_unlocked(id):
		var prereq      = UpgradeManager.get_def(upgrade.prerequisite_id)
		var prereq_name = prereq.display_name if prereq else upgrade.prerequisite_id
		card.cost.text       = "Lv " + str(upgrade.prerequisite_level)
		card.cost.add_theme_color_override("font_color", COL_LOCKED)
		card.buy.text        = "🔒 " + prereq_name
		card.buy.disabled    = true
		card.root.modulate   = Color(0.6, 0.6, 0.6, 1.0)
		_style_buy(card.buy, COL_CARD, COL_LOCKED)
		return

	card.root.modulate = Color(1, 1, 1, 1)

	# ─── MAXED
	if level >= upgrade.max_level:
		card.cost.text    = "MAX"
		card.cost.add_theme_color_override("font_color", accent)
		card.buy.text     = "✓"
		card.buy.disabled = true
		_style_buy(card.buy, COL_CARD, accent)
		return

	# ─── BUYABLE
	var cost = UpgradeManager.get_cost(id)
	var affordable = GameManager.sucrose >= cost
	card.cost.text = str(int(cost))
	card.cost.add_theme_color_override("font_color", accent if affordable else COL_DIM)
	card.buy.text     = "BUY"
	card.buy.disabled = not affordable
	if affordable:
		_style_buy(card.buy, accent, Color(0.08, 0.08, 0.10))
	else:
		_style_buy(card.buy, COL_CARD, COL_DIM)

# ─── Re-skin a button with a flat bg + text color
func _style_buy(btn: Button, bg: Color, fg: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("disabled", sb)
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_disabled_color", fg)

func _on_sucrose_changed() -> void:
	# ─── Cheap: only re-evaluate buy buttons + cost colors, no rebuild
	for card in _cards:
		_refresh_card(card)
	_update_sucrose_text()

func _update_sucrose_text() -> void:
	if _sucrose_label:
		_sucrose_label.text = "🍯 " + str(int(GameManager.sucrose))

# =============================================================================
# UPGRADE REGISTRATION — unchanged content, still the single catalog source
# =============================================================================
func _register_upgrades() -> void:
	_register("faster_legs",      "Faster Legs",      "Ants move 10% faster",          50.0,   1.5, 10, "",                0)
	_register("sprinter_genes",   "Sprinter Genes",   "+5% speed, raises the cap",     1500.0, 2.0, 5,  "faster_legs",     10)
	_register("faster_hatchery",  "Faster Hatchery",  "+0.05 spawn boost per level",   30.0,   1.4, 20, "",                0)
	_register("royal_pheromones", "Royal Pheromones", "+0.10 spawn boost per level",   1000.0, 1.8, 10, "faster_hatchery", 20)
	_register("better_nose",      "Better Nose",      "Ants detect food 50% further",  75.0,   1.5, 10, "",                0)
	_register("hawk_eyes",        "Hawk Eyes",        "+25% food detection radius",    2000.0, 2.0, 5,  "better_nose",     10)
	_register("click_influence",  "Click Influence",  "+1 ant follows your rally",     100.0,  1.6, 10, "",                0)
	_register("bigger_colony",    "Bigger Colony",    "Instantly spawn 20 ants",       200.0,  1.7, 10, "",                0)

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
