class_name HeroDefs
extends RefCounted

## Starter roster. After Mid Boss, players may Ascend (god form) once.


static func all() -> Array[Dictionary]:
	return [
		{
			"id": "seraph",
			"name": "Seraph",
			"role": "Support / Burst",
			"primary": "int",
			"blurb": "Radiant striker. Heals allies and smites foes — farm mid, win duels.",
			"color": Color(0.95, 0.9, 0.75),
			"sprite": "res://assets/sprites/hero_seraph.png",
			"max_hp": 580.0,
			"max_mana": 340.0,
			"armor": 3.0,
			"move_speed": 210.0,
			"attack_damage": 38.0,
			"attack_range": 165.0,
			"attack_cooldown": 0.85,
			"str": 14.0, "agi": 12.0, "intel": 22.0,
			"abilities": ["smite", "mending_light", "ascendant_burst"],
			"god_name": "Archon",
		},
		{
			"id": "ashwalker",
			"name": "Ashwalker",
			"role": "Melee Carry",
			"primary": "agi",
			"blurb": "Ember duelist. Clears camps fast, closes gaps in the duel ring.",
			"color": Color(0.85, 0.35, 0.2),
			"sprite": "res://assets/sprites/hero_ashwalker.png",
			"max_hp": 700.0,
			"max_mana": 200.0,
			"armor": 5.0,
			"move_speed": 225.0,
			"attack_damage": 48.0,
			"attack_range": 70.0,
			"attack_cooldown": 0.68,
			"str": 16.0, "agi": 22.0, "intel": 10.0,
			"abilities": ["cinder_dash", "scorch", "inferno_form"],
			"god_name": "Infernal",
		},
		{
			"id": "tidebound",
			"name": "Tidebound",
			"role": "Control Mage",
			"primary": "int",
			"blurb": "Ocean binder. Slows packs while farming, locks foes in duels.",
			"color": Color(0.25, 0.45, 0.75),
			"sprite": "res://assets/sprites/hero_tidebound.png",
			"max_hp": 520.0,
			"max_mana": 400.0,
			"armor": 2.0,
			"move_speed": 205.0,
			"attack_damage": 34.0,
			"attack_range": 195.0,
			"attack_cooldown": 0.9,
			"str": 12.0, "agi": 11.0, "intel": 24.0,
			"abilities": ["rip_current", "undertow", "tidal_crash"],
			"god_name": "Leviathan",
		},
		{
			"id": "thornwight",
			"name": "Thornwight",
			"role": "Durable Bruiser",
			"primary": "str",
			"blurb": "Rooted guardian. Soaks camp damage and anchors teamfights.",
			"color": Color(0.25, 0.5, 0.28),
			"sprite": "res://assets/sprites/hero_thornwight.png",
			"max_hp": 820.0,
			"max_mana": 220.0,
			"armor": 7.0,
			"move_speed": 198.0,
			"attack_damage": 44.0,
			"attack_range": 75.0,
			"attack_cooldown": 0.8,
			"str": 24.0, "agi": 12.0, "intel": 10.0,
			"abilities": ["bramble_skin", "root_snare", "overgrowth"],
			"god_name": "Worldroot",
		},
	]


static func by_id(hero_id: String) -> Dictionary:
	for h in all():
		if h["id"] == hero_id:
			return h
	return all()[0]


static func ability_info(ability_id: String) -> Dictionary:
	var table := {
		"smite": {"name": "Smite", "mana": 40.0, "cooldown": 5.0, "desc": "Holy bolt to nearest foe."},
		"mending_light": {"name": "Mending", "mana": 50.0, "cooldown": 8.0, "desc": "Heal yourself."},
		"ascendant_burst": {"name": "Burst", "mana": 90.0, "cooldown": 16.0, "desc": "Nova around you."},
		"cinder_dash": {"name": "Dash", "mana": 35.0, "cooldown": 6.0, "desc": "Dash toward your aim."},
		"scorch": {"name": "Scorch", "mana": 45.0, "cooldown": 7.0, "desc": "Burn nearest enemy."},
		"inferno_form": {"name": "Inferno", "mana": 80.0, "cooldown": 18.0, "desc": "Attack power surge."},
		"rip_current": {"name": "Rip", "mana": 40.0, "cooldown": 6.0, "desc": "Slow and damage a foe."},
		"undertow": {"name": "Undertow", "mana": 55.0, "cooldown": 10.0, "desc": "Pull nearby enemies."},
		"tidal_crash": {"name": "Crash", "mana": 95.0, "cooldown": 17.0, "desc": "Wave burst."},
		"bramble_skin": {"name": "Bramble", "mana": 30.0, "cooldown": 9.0, "desc": "Reflect damage."},
		"root_snare": {"name": "Root", "mana": 45.0, "cooldown": 8.0, "desc": "Root nearest foe."},
		"overgrowth": {"name": "Growth", "mana": 85.0, "cooldown": 18.0, "desc": "Spike nova + armor."},
	}
	return table.get(ability_id, {"name": ability_id, "mana": 40.0, "cooldown": 6.0, "desc": ""})
