class_name ArenaBuilder
extends RefCounted

## Builds a large Angel Arena–inspired floating-island map over purple void.


static func build(world: Node2D, arena_size: Vector2, mid: Vector2, shop_pos: Dictionary) -> void:
	var ground := Node2D.new()
	ground.name = "Ground"
	world.add_child(ground)
	world.move_child(ground, 0)

	# Void backdrop
	var void_spr := Sprite2D.new()
	void_spr.centered = false
	void_spr.position = Vector2(-200, -200)
	var void_tex := _make_void_tex()
	void_spr.texture = void_tex
	void_spr.scale = Vector2((arena_size.x + 400) / 64.0, (arena_size.y + 400) / 64.0)
	ground.add_child(void_spr)

	var grass := load("res://assets/tiles/grass.png")
	var dirt := load("res://assets/tiles/dirt.png")
	var stone := load("res://assets/tiles/stone.png")
	var base_a := load("res://assets/tiles/base_angel.png")
	var base_d := load("res://assets/tiles/base_demon.png")

	# Paint playable platforms as islands rather than a full rectangle
	_fill_rect(ground, Rect2(mid.x - 420, 80, 840, 520), base_a) ## angel base
	_fill_rect(ground, Rect2(mid.x - 420, arena_size.y - 600, 840, 520), base_d) ## ashen base
	_fill_ellipse(ground, mid, 520, 420, stone) ## mid duel plate
	_fill_rect(ground, Rect2(mid.x - 90, 560, 180, arena_size.y - 1120), dirt) ## north-south road
	_fill_rect(ground, Rect2(400, mid.y - 80, arena_size.x - 800, 160), dirt) ## east-west road

	# Camp islands
	for camp in CampDefs.camps():
		var cpos: Vector2 = camp["pos"]
		var tier: String = camp["tier"]
		var tex: Texture2D = grass
		if tier == "medium":
			tex = dirt
		elif tier == "hard":
			tex = stone
		_fill_ellipse(ground, cpos, 110, 90, tex)

	# Mid shop island pads
	_fill_ellipse(ground, shop_pos["mid"], 90, 70, stone)
	_fill_ellipse(ground, shop_pos["secret"], 90, 70, stone)

	_marker(world, "BaseShopLight", load("res://assets/sprites/shop.png"), shop_pos["base_light"])
	_marker(world, "BaseShopDark", load("res://assets/sprites/shop.png"), shop_pos["base_dark"])
	_marker(world, "MidShop", load("res://assets/sprites/shop.png"), shop_pos["mid"])
	var secret := _marker(world, "SecretShop", load("res://assets/sprites/shop.png"), shop_pos["secret"])
	secret.modulate = Color(0.6, 0.6, 0.6, 0.55)
	_marker(world, "FountainLight", load("res://assets/sprites/fountain_angel.png"), Vector2(mid.x, 180))
	_marker(world, "FountainDark", load("res://assets/sprites/fountain_demon.png"), Vector2(mid.x, arena_size.y - 180))

	# Duel ring
	var ring := Line2D.new()
	ring.width = 5.0
	ring.default_color = Color(0.95, 0.8, 0.35, 0.55)
	ring.closed = true
	var pts: PackedVector2Array = []
	for i in 40:
		var a := TAU * float(i) / 40.0
		pts.append(mid + Vector2(cos(a) * 240.0, sin(a) * 200.0))
	ring.points = pts
	ring.z_index = 2
	world.add_child(ring)

	_zone(world, "ANGEL BASE", Vector2(mid.x, 120), Color(0.75, 0.85, 1.0))
	_zone(world, "DUEL RING", mid + Vector2(0, -260), Color(0.95, 0.85, 0.4))
	_zone(world, "ASHEN BASE", Vector2(mid.x, arena_size.y - 120), Color(1.0, 0.65, 0.55))
	_zone(world, "MID SHOP", shop_pos["mid"] + Vector2(0, 40), Color(0.9, 0.8, 0.45))
	_zone(world, "SECRET", shop_pos["secret"] + Vector2(0, 40), Color(0.75, 0.55, 1.0))

	for camp in CampDefs.camps():
		var tier: String = camp["tier"]
		var color := Color(0.45, 0.85, 0.5, 0.6)
		var title := "EASY"
		match tier:
			"medium":
				color = Color(0.95, 0.75, 0.25, 0.65)
				title = "MED"
			"hard":
				color = Color(0.95, 0.35, 0.3, 0.7)
				title = "HARD"
		var cr := Line2D.new()
		cr.width = 3.0
		cr.default_color = color
		cr.closed = true
		var cpts: PackedVector2Array = []
		var center: Vector2 = camp["pos"]
		for i in 24:
			var a := TAU * float(i) / 24.0
			cpts.append(center + Vector2(cos(a), sin(a)) * 70.0)
		cr.points = cpts
		cr.z_index = 1
		world.add_child(cr)
		_zone(world, title, center + Vector2(0, -82), color)


static func _make_void_tex() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.09, 0.04, 0.14, 1))
	## Soft vignette noise — avoid harsh checker look
	for y in 64:
		for x in 64:
			if ((x + y * 3) % 17) == 0:
				img.set_pixel(x, y, Color(0.13, 0.06, 0.2, 1))
	return ImageTexture.create_from_image(img)


static func _fill_rect(ground: Node2D, rect: Rect2, tex: Texture2D) -> void:
	var x0 := int(rect.position.x)
	var y0 := int(rect.position.y)
	var x1 := int(rect.position.x + rect.size.x)
	var y1 := int(rect.position.y + rect.size.y)
	for y in range(y0, y1, 64):
		for x in range(x0, x1, 64):
			var spr := Sprite2D.new()
			spr.centered = false
			spr.position = Vector2(x, y)
			spr.texture = tex
			ground.add_child(spr)


static func _fill_ellipse(ground: Node2D, center: Vector2, rx: float, ry: float, tex: Texture2D) -> void:
	var x0 := int(center.x - rx)
	var y0 := int(center.y - ry)
	var x1 := int(center.x + rx)
	var y1 := int(center.y + ry)
	for y in range(y0, y1, 64):
		for x in range(x0, x1, 64):
			var dx := (x + 32 - center.x) / rx
			var dy := (y + 32 - center.y) / ry
			if dx * dx + dy * dy > 1.05:
				continue
			var spr := Sprite2D.new()
			spr.centered = false
			spr.position = Vector2(x, y)
			spr.texture = tex
			ground.add_child(spr)


static func _marker(world: Node2D, p_name: String, tex: Texture2D, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = p_name
	s.texture = tex
	s.position = pos
	s.z_index = 1
	world.add_child(s)
	return s


static func _zone(world: Node2D, text: String, pos: Vector2, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos - Vector2(60, 0)
	l.modulate = color
	l.z_index = 2
	world.add_child(l)
