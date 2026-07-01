extends PanelContainer

# ═══════════════════════════════════════════════════════════════════════
# 🎨 STYLE — EVERYTHING about how this panel looks is set HERE. Nowhere else.
# Tweak a number, run, see it change. Bigger number = bigger / clearer.
# ═══════════════════════════════════════════════════════════════════════

# ── FONT ──  Put your font path here. If the file is missing it silently
#            falls back to Godot's default, so this never crashes.
const FONT_PATH: String = "res://Assets/Fonts/Jenko-DEMO.ttf"

# ── TEXT SIZES ──  (these were ~15–30 before — way too small on a phone)
const SIZE_TITLE:   int = 52
const SIZE_SUCROSE: int = 34
const SIZE_SECTION: int = 30
const SIZE_NAME:    int = 38
const SIZE_DESC:    int = 26
const SIZE_COST:    int = 30
const SIZE_BUY:     int = 32
const SIZE_CLOSE:   int = 32

# ── TEXT COLORS ──
const TEXT_MAIN:   Color = Color(0.95, 0.96, 0.98)        # names, title
const TEXT_DIM:    Color = Color(0.95, 0.96, 0.98, 0.55)  # descriptions
const TEXT_LOCKED: Color = Color(0.55, 0.57, 0.62)        # locked cards
const TEXT_ON_BUY: Color = Color(0.08, 0.08, 0.10)        # text on a bright BUY

# ── PANEL & CARD COLORS ──
const BG_PANEL: Color = Color(0.09, 0.10, 0.12)
const BG_CARD:  Color = Color(0.15, 0.16, 0.20)

# ── SPACING & SHAPE ──  (pixels)
const PANEL_PADDING: int = 24
const CARD_PADDING:  int = 18
const CARD_GAP:      int = 16
const SECTION_GAP:   int = 18
const CORNER_PANEL:  int = 20
const CORNER_CARD:   int = 14
const BUY_WIDTH:     int = 150
const BAR_HEIGHT:    int = 8

# ═══════════════════════════════════════════════════════════════════════
# QUEEN ACCENTS — the one highlight colour, themed per species.
# Auto-switches on prestige. Anything unlisted falls back to amber.
# ═══════════════════════════════════════════════════════════════════════
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
# STATE
# =============================================================================
var _cards: Array = []          # each: {id, root, sb, name, desc, cost, buy, bar}
var _sucrose_label: Label = null
var _font: Font = null

# =============================================================================
# READY
# =============================================================================
func _ready() -> void:
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)
	_build_ui()
	EventBus.sucrose_changed.connect(func(_a): _on_sucrose_changed())
	EventBus.upgrade_purchased.connect(func(_id): _refresh_all())
	EventBus.colony_loaded.connect(func(_c): _build_ui())   # re-theme on prestige

# =============================================================================
# SHARED STYLE HELPERS — every label/button goes through these
# =============================================================================
func _make_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	if _font:
		l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _font_button(btn: Button, size: int) -> void:
	if _font:
		btn.add_theme_font_override("font", _font)
	btn.add_theme_font_size_override("font_size", size)

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
	sb.bg_color = BG_PANEL
	sb.set_corner_radius_all(CORNER_PANEL)
	sb.set_content_margin_all(0)
	add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", PANEL_PADDING)
	margin.add_theme_constant_override("margin_right", PANEL_PADDING)
	margin.add_theme_constant_override("margin_top", PANEL_PADDING)
	margin.add_theme_constant_override("margin_bottom", PANEL_PADDING)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", SECTION_GAP)
	margin.add_child(root)

	root.add_child(_build_header(accent))
	root.add_child(_build_scroll(accent))

# ─── Header: title + live sucrose + close
func _build_header(accent: Color) -> VBoxContainer:
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 6)

	var row := HBoxContainer.new()
	head.add_child(row)

	var title := _make_label("UPGRADES", SIZE_TITLE, TEXT_MAIN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)

	_sucrose_label = _make_label("", SIZE_SUCROSE, accent)
	_sucrose_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_update_sucrose_text()
	row.add_child(_sucrose_label)

	var close := Button.new()
	close.text = "✕"
	_font_button(close, SIZE_CLOSE)
	close.pressed.connect(func(): hide())
	row.add_child(close)

	# ─── Accent underline
	var underline := ColorRect.new()
	underline.color = accent
	underline.custom_minimum_size.y = 4
	head.add_child(underline)

	return head

# ─── Scrollable list of sections — order + grouping come from the CATALOG
func _build_scroll(accent: Color) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", CARD_GAP)
	scroll.add_child(list)

	for branch in UpgradeManager.get_branch_order():
		list.add_child(_make_label(branch, SIZE_SECTION, accent))
		for id in UpgradeManager.get_ids_in_branch(branch):
			if UpgradeManager.get_def(id):
				var card = _build_card(id, accent)
				list.add_child(card.root)
				_cards.append(card)

	_refresh_all()
	return scroll

# =============================================================================
# CARD — built in code, refreshed in place (no rebuild on sucrose ticks)
# =============================================================================
func _build_card(id: String, accent: Color) -> Dictionary:
	var upgrade = UpgradeManager.get_def(id)

	var root := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_CARD
	sb.set_corner_radius_all(CORNER_CARD)
	sb.set_content_margin_all(CARD_PADDING)
	root.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	root.add_child(hbox)

	# Left — name + description + level bar
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	hbox.add_child(left)

	var name_label := _make_label(upgrade.display_name, SIZE_NAME, TEXT_MAIN)
	left.add_child(name_label)

	var desc_label := _make_label(upgrade.description, SIZE_DESC, TEXT_DIM)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(desc_label)

	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = BAR_HEIGHT
	bar.max_value = upgrade.max_level
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0, 0, 0, 0.35)
	bar_bg.set_corner_radius_all(4)
	var bar_fg := StyleBoxFlat.new()
	bar_fg.bg_color = accent
	bar_fg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bar_bg)
	bar.add_theme_stylebox_override("fill", bar_fg)
	left.add_child(bar)

	# Right — cost + buy
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.custom_minimum_size.x = BUY_WIDTH
	hbox.add_child(right)

	var cost_label := _make_label("", SIZE_COST, TEXT_MAIN)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(cost_label)

	var buy := Button.new()
	_font_button(buy, SIZE_BUY)
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
		card.cost.add_theme_color_override("font_color", TEXT_LOCKED)
		card.buy.text        = "🔒 " + prereq_name
		card.buy.disabled    = true
		card.root.modulate   = Color(0.6, 0.6, 0.6, 1.0)
		_style_buy(card.buy, BG_CARD, TEXT_LOCKED)
		return

	card.root.modulate = Color(1, 1, 1, 1)

	# ─── MAXED
	if level >= upgrade.max_level:
		card.cost.text    = "MAX"
		card.cost.add_theme_color_override("font_color", accent)
		card.buy.text     = "✓"
		card.buy.disabled = true
		_style_buy(card.buy, BG_CARD, accent)
		return

	# ─── BUYABLE
	var cost = UpgradeManager.get_cost(id)
	var affordable = GameManager.sucrose >= cost
	card.cost.text = str(int(cost))
	card.cost.add_theme_color_override("font_color", accent if affordable else TEXT_DIM)
	card.buy.text     = "BUY"
	card.buy.disabled = not affordable
	if affordable:
		_style_buy(card.buy, accent, TEXT_ON_BUY)
	else:
		_style_buy(card.buy, BG_CARD, TEXT_DIM)

# ─── Re-skin a button with a flat bg + text color
func _style_buy(btn: Button, bg: Color, fg: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("disabled", sb)
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_disabled_color", fg)

func _on_sucrose_changed() -> void:
	# ─── Cheap: only re-evaluate buy buttons + cost colors, no full rebuild
	for card in _cards:
		_refresh_card(card)
	_update_sucrose_text()

func _update_sucrose_text() -> void:
	if _sucrose_label:
		_sucrose_label.text = "🍯 " + str(int(GameManager.sucrose))
