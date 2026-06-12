extends Node2D

# ─── FOOD TYPES ───────────────────────────────────────────────────────────────
enum FoodType { LEAF, INSECT, SUGAR_CRYSTAL, SUCROSE_DROP, MUSHROOM, SEED, ROYAL_JELLY }


# ─── STATS PER TYPE ───────────────────────────────────────────────────────────
const FOOD_DATA = {
	FoodType.LEAF:         {"reward": 1.0,  "retrieve_mult": 1.0,  "bites": 5,  "label": "Leaf"},
	FoodType.INSECT:       {"reward": 2.5,  "retrieve_mult": 1.8,  "bites": 8,  "label": "Insect"},
	FoodType.SUGAR_CRYSTAL:{"reward": 3.5,  "retrieve_mult": 0.8,  "bites": 4,  "label": "Sugar Crystal"},
	FoodType.SUCROSE_DROP: {"reward": 10.0, "retrieve_mult": 0.4,  "bites": 2,  "label": "Sucrose Drop"},
	FoodType.MUSHROOM:     {"reward": 1.8,  "retrieve_mult": 1.3,  "bites": 6,  "label": "Mushroom"},
	FoodType.SEED:         {"reward": 0.8,  "retrieve_mult": 0.6,  "bites": 3,  "label": "Seed"},
	FoodType.ROYAL_JELLY:  {"reward": 0.5,  "retrieve_mult": 2.0,  "bites": 3,  "label": "Royal Jelly", "boost": 0.15},
}

# Spawn weights — higher = more common
const SPAWN_WEIGHTS = {
	FoodType.LEAF:          40,
	FoodType.INSECT:        25,
	FoodType.SUGAR_CRYSTAL: 18,
	FoodType.SUCROSE_DROP:  5,
	FoodType.MUSHROOM:      22,
	FoodType.SEED:          30,
	FoodType.ROYAL_JELLY:   3,
}

# ─── STATE ────────────────────────────────────────────────────────────────────
var food_type: FoodType = FoodType.LEAF
var sucrose_reward: float = 1.0
var retrieve_time_mult: float = 1.0
var boost_value: float = 0.0          # ← ADD THIS LINE
var _bites_remaining: int = 5
var _noise_time: float = 0.0

func _ready() -> void:
	add_to_group("foods")
	food_type = _pick_weighted_type()
	var data = FOOD_DATA[food_type]
	sucrose_reward     = data.reward
	retrieve_time_mult = data.retrieve_mult
	_bites_remaining   = data.bites
	# Randomise size and rotation for natural variety
	var s = randf_range(0.7, 1.3)
	scale    = Vector2(s, s)
	rotation = randf() * TAU
	GameManager.register_food(self)
	queue_redraw()
	sucrose_reward     = data.reward
	retrieve_time_mult = data.retrieve_mult
	_bites_remaining   = data.bites
	boost_value        = data.get("boost", 0.0)    # ← ADD THIS LINE

func _process(delta: float) -> void:
	if food_type == FoodType.SUCROSE_DROP or food_type == FoodType.ROYAL_JELLY:
		_noise_time += delta
		queue_redraw()

func bite() -> void:
	# Reduce remaining bites, shrink visually, free when exhausted
	_bites_remaining -= 1
	scale *= 0.9
	queue_redraw()
	if _bites_remaining <= 0:
		GameManager.unregister_food(self)
		queue_free()

# ─── WEIGHTED RANDOM TYPE PICKER ──────────────────────────────────────────────
func _pick_weighted_type() -> FoodType:
	var total = 0
	for w in SPAWN_WEIGHTS.values():
		total += w
	var roll = randi() % total
	var cumulative = 0
	for type in SPAWN_WEIGHTS.keys():
		cumulative += SPAWN_WEIGHTS[type]
		if roll < cumulative:
			return type
	return FoodType.LEAF

# ─── DRAWING ──────────────────────────────────────────────────────────────────
func _draw() -> void:
	match food_type:
		FoodType.LEAF:         _draw_leaf()
		FoodType.INSECT:       _draw_insect()
		FoodType.SUGAR_CRYSTAL: _draw_sugar_crystal()
		FoodType.SUCROSE_DROP: _draw_sucrose_drop()
		FoodType.MUSHROOM:     _draw_mushroom()
		FoodType.SEED:         _draw_seed()
		FoodType.ROYAL_JELLY:  _draw_royal_jelly()

func _draw_royal_jelly() -> void:
	# Glowing amber blob — precious and rare
	var pulse = abs(sin(_noise_time * 3.0)) * 0.15
	var amber = Color(1.0, 0.75 + pulse, 0.3, 0.95)
	# Main blob — organic shape using overlapping circles
	draw_circle(Vector2(0, 0), 10.0, amber)
	draw_circle(Vector2(-4, -3), 7.0, amber.lightened(0.15))
	draw_circle(Vector2(3, 2), 6.0, amber.lightened(0.1))
	# Inner glow
	draw_circle(Vector2(-1, -1), 4.0, Color(1.0, 0.95, 0.6, 0.8))
	draw_circle(Vector2(0, 0), 2.0, Color(1.0, 1.0, 0.9, 0.9))
	# Crown sparkle — so player knows this is special
	draw_line(Vector2(0, -12), Vector2(0, -16), Color(1.0, 0.9, 0.4, 0.7 + pulse), 1.5)
	draw_line(Vector2(-4, -10), Vector2(-6, -14), Color(1.0, 0.9, 0.4, 0.5 + pulse), 1.2)
	draw_line(Vector2(4, -10), Vector2(6, -14), Color(1.0, 0.9, 0.4, 0.5 + pulse), 1.2)

func _draw_leaf() -> void:
	# Green diamond leaf shape with vein
	var points = PackedVector2Array([
		Vector2(0, -18), Vector2(10, 0), Vector2(0, 18), Vector2(-10, 0)
	])
	draw_polygon(points, PackedColorArray([Color(0.2, 0.7, 0.15, 0.95)]))
	# Vein down center
	draw_line(Vector2(0, -18), Vector2(0, 18), Color(0.1, 0.5, 0.1, 0.8), 1.2)
	# Small side veins
	draw_line(Vector2(0, -6), Vector2(7, 2),  Color(0.1, 0.5, 0.1, 0.6), 0.8)
	draw_line(Vector2(0, -6), Vector2(-7, 2), Color(0.1, 0.5, 0.1, 0.6), 0.8)

func _draw_insect() -> void:
	# Brown oval body with 6 legs and small head
	var body_color = Color(0.45, 0.28, 0.12, 0.95)
	var leg_color  = Color(0.3, 0.18, 0.08, 0.9)
	# Legs — 3 per side
	for i in 3:
		var y = -6.0 + i * 6.0
		draw_line(Vector2(-8, y), Vector2(-16, y + 4), leg_color, 1.0)
		draw_line(Vector2(8,  y), Vector2(16,  y + 4), leg_color, 1.0)
	# Body
	draw_circle(Vector2(0, 0), 9.0,  body_color)
	draw_circle(Vector2(0, 0), 5.5,  body_color.lightened(0.1))
	# Head
	draw_circle(Vector2(0, -13), 5.0, body_color.darkened(0.1))
	# Eyes
	draw_circle(Vector2(-2, -14), 1.2, Color(0.9, 0.2, 0.1))
	draw_circle(Vector2(2,  -14), 1.2, Color(0.9, 0.2, 0.1))

func _draw_sugar_crystal() -> void:
	# Blue/white diamond crystal shape with shine
	var points = PackedVector2Array([
		Vector2(0, -20), Vector2(12, -4), Vector2(8, 14),
		Vector2(-8, 14), Vector2(-12, -4)
	])
	draw_polygon(points, PackedColorArray([Color(0.55, 0.8, 1.0, 0.85)]))
	# Inner highlight
	var inner = PackedVector2Array([
		Vector2(0, -14), Vector2(7, -2), Vector2(4, 8),
		Vector2(-4, 8), Vector2(-7, -2)
	])
	draw_polygon(inner, PackedColorArray([Color(0.85, 0.95, 1.0, 0.5)]))
	# Shine dot
	draw_circle(Vector2(-3, -8), 3.0, Color(1.0, 1.0, 1.0, 0.8))

func _draw_sucrose_drop() -> void:
	# Rare golden hexagon with glow and sparkles
	var pulse = abs(sin(_noise_time * 2.5)) * 0.3
	var gold  = Color(1.0, 0.78 + pulse * 0.2, 0.0, 0.95)
	# Hexagon
	var hex = PackedVector2Array()
	for i in 6:
		var angle = i * TAU / 6.0
		hex.append(Vector2(cos(angle), sin(angle)) * 14.0)
	draw_polygon(hex, PackedColorArray([gold]))
	# Inner bright center
	draw_circle(Vector2.ZERO, 7.0, Color(1.0, 0.95, 0.5, 0.9))
	draw_circle(Vector2.ZERO, 3.0, Color(1.0, 1.0, 1.0, 0.9))
	# Sparkle lines
	for i in 4:
		var angle = i * TAU / 4.0 + _noise_time
		var tip = Vector2(cos(angle), sin(angle)) * (18.0 + pulse * 4.0)
		draw_line(Vector2.ZERO, tip, Color(1.0, 0.9, 0.3, 0.5 + pulse * 0.3), 1.0)

func _draw_mushroom() -> void:
	# Purple cap with tan stem
	var cap_color  = Color(0.6, 0.2, 0.7, 0.9)
	var stem_color = Color(0.85, 0.75, 0.55, 0.9)
	var spot_color = Color(1.0, 1.0, 1.0, 0.6)
	# Stem
	draw_rect(Rect2(-5, 2, 10, 12), stem_color)
	# Cap — semicircle using polygon
	var cap = PackedVector2Array()
	cap.append(Vector2(-14, 4))
	for i in 13:
		var angle = PI + i * PI / 12.0
		cap.append(Vector2(cos(angle), sin(angle)) * 14.0)
	cap.append(Vector2(14, 4))
	draw_polygon(cap, PackedColorArray([cap_color]))
	# White spots on cap
	draw_circle(Vector2(-5, -4), 2.5, spot_color)
	draw_circle(Vector2(4,  -7), 2.0, spot_color)
	draw_circle(Vector2(0,  -2), 1.5, spot_color)

func _draw_seed() -> void:
	# Tan teardrop seed shape
	var seed_color = Color(0.8, 0.65, 0.35, 0.95)
	var tip_color  = Color(0.55, 0.4, 0.18, 0.9)
	# Body — oval
	draw_circle(Vector2(0, 2), 8.0,  seed_color)
	draw_circle(Vector2(0, 0), 6.0,  seed_color)
	# Pointed tip
	var tip = PackedVector2Array([
		Vector2(-4, -4), Vector2(4, -4), Vector2(0, -14)
	])
	draw_polygon(tip, PackedColorArray([tip_color]))
	# Stripe down center
	draw_line(Vector2(0, -14), Vector2(0, 10), Color(0.45, 0.3, 0.1, 0.5), 0.8)

# Returns 0.0 to 1.0 health percentage for progress bar
func get_health_pct() -> float:
	return float(_bites_remaining) / float(FOOD_DATA[food_type].bites)

# Returns readable label for the log
func get_type_label() -> String:
	return FOOD_DATA[food_type].label
