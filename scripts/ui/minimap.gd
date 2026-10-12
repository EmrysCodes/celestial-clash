extends Control

## Radar of camps, shops, heroes, and mid boss on the large AA map.

@export var map_size := Vector2(3600, 3600)
@export var radar_size := Vector2(148, 148)

var match_ref: Node2D = null


func setup(controller: Node2D) -> void:
	match_ref = controller
	if match_ref and "ARENA_SIZE" in match_ref:
		map_size = match_ref.ARENA_SIZE
	custom_minimum_size = radar_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if match_ref == null:
		return
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.08, 0.04, 0.12, 0.88))
	draw_rect(rect, Color(0.83, 0.69, 0.22, 0.7), false, 2.0)

	_dot(Vector2(map_size.x * 0.5, 180), Color(0.55, 0.75, 1.0), 4.0)
	_dot(Vector2(map_size.x * 0.5, map_size.y - 180), Color(1.0, 0.45, 0.4), 4.0)
	_dot(match_ref.MID_POS, Color(0.95, 0.8, 0.3, 0.5), 9.0)
	_dot(match_ref.SHOP_POS["base_light"], Color(0.9, 0.8, 0.4), 3.0)
	_dot(match_ref.SHOP_POS["mid"], Color(0.9, 0.8, 0.4), 3.0)
	_dot(match_ref.SHOP_POS["secret"], Color(0.7, 0.5, 1.0) if match_ref.secret_unlocked else Color(0.35, 0.35, 0.4), 3.0)

	for camp_id in match_ref.camp_states.keys():
		var camp: Dictionary = match_ref.camp_states[camp_id]["def"]
		var color := Color(0.5, 0.9, 0.5)
		match String(camp["tier"]):
			"medium":
				color = Color(0.95, 0.75, 0.3)
			"hard":
				color = Color(0.95, 0.4, 0.35)
		_dot(camp["pos"], color, 3.0)

	for u in match_ref.units:
		if u == null or not u.alive:
			continue
		if u.unit_kind == CombatUnit.Kind.BOSS:
			_dot(u.global_position, Color(1.0, 0.85, 0.2), 5.0)
		elif u.unit_kind == CombatUnit.Kind.HERO:
			var c := Color(0.4, 0.9, 1.0) if u.team == GameSession.TEAM_LIGHT else Color(1.0, 0.35, 0.35)
			if u == match_ref.player_unit:
				c = Color(1.0, 1.0, 1.0)
			_dot(u.global_position, c, 3.2)


func _dot(world_pos: Vector2, color: Color, radius: float) -> void:
	var local := Vector2(
		(world_pos.x / map_size.x) * size.x,
		(world_pos.y / map_size.y) * size.y
	)
	draw_circle(local, radius, color)


func _process(_delta: float) -> void:
	queue_redraw()
