class_name CampDefs
extends RefCounted

## Angel Arena–style camp ring around a large mid arena.
## Coordinate space: 3600×3600, mid = (1800, 1800).


static func camps() -> Array:
	return [
		# Near Angel base (north) — easy farms
		{"id": "easy_n1", "tier": "easy", "pos": Vector2(1280, 620), "team_side": 0, "count": 3, "respawn": 16.0},
		{"id": "easy_n2", "tier": "easy", "pos": Vector2(2320, 620), "team_side": 0, "count": 3, "respawn": 16.0},
		{"id": "easy_n3", "tier": "easy", "pos": Vector2(1800, 780), "team_side": 0, "count": 3, "respawn": 16.0},
		# Near Ashen base (south)
		{"id": "easy_s1", "tier": "easy", "pos": Vector2(1280, 2980), "team_side": 1, "count": 3, "respawn": 16.0},
		{"id": "easy_s2", "tier": "easy", "pos": Vector2(2320, 2980), "team_side": 1, "count": 3, "respawn": 16.0},
		{"id": "easy_s3", "tier": "easy", "pos": Vector2(1800, 2820), "team_side": 1, "count": 3, "respawn": 16.0},
		# Side islands — medium
		{"id": "med_w1", "tier": "medium", "pos": Vector2(520, 1500), "team_side": -1, "count": 3, "respawn": 22.0},
		{"id": "med_w2", "tier": "medium", "pos": Vector2(520, 2100), "team_side": -1, "count": 3, "respawn": 22.0},
		{"id": "med_e1", "tier": "medium", "pos": Vector2(3080, 1500), "team_side": -1, "count": 3, "respawn": 22.0},
		{"id": "med_e2", "tier": "medium", "pos": Vector2(3080, 2100), "team_side": -1, "count": 3, "respawn": 22.0},
		# Hard pockets near mid
		{"id": "hard_nw", "tier": "hard", "pos": Vector2(1100, 1400), "team_side": -1, "count": 2, "respawn": 28.0},
		{"id": "hard_ne", "tier": "hard", "pos": Vector2(2500, 1400), "team_side": -1, "count": 2, "respawn": 28.0},
		{"id": "hard_sw", "tier": "hard", "pos": Vector2(1100, 2200), "team_side": -1, "count": 2, "respawn": 28.0},
		{"id": "hard_se", "tier": "hard", "pos": Vector2(2500, 2200), "team_side": -1, "count": 2, "respawn": 28.0},
		# Corner elite islands
		{"id": "elite_nw", "tier": "hard", "pos": Vector2(700, 900), "team_side": -1, "count": 2, "respawn": 32.0},
		{"id": "elite_se", "tier": "hard", "pos": Vector2(2900, 2700), "team_side": -1, "count": 2, "respawn": 32.0},
	]


static func tier_stats(tier: String) -> Dictionary:
	match tier:
		"easy":
			return {"hp": 110.0, "dmg": 12.0, "armor": 0.0, "gold": 45, "xp": 28.0, "speed": 120.0}
		"medium":
			return {"hp": 220.0, "dmg": 22.0, "armor": 2.0, "gold": 95, "xp": 55.0, "speed": 130.0}
		"hard":
			return {"hp": 420.0, "dmg": 38.0, "armor": 4.0, "gold": 180, "xp": 90.0, "speed": 140.0}
		"boss":
			return {"hp": 4200.0, "dmg": 78.0, "armor": 11.0, "gold": 1100, "xp": 480.0, "speed": 150.0}
		_:
			return {"hp": 100.0, "dmg": 10.0, "armor": 0.0, "gold": 40, "xp": 20.0, "speed": 120.0}
