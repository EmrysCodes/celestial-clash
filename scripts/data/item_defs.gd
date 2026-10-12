class_name ItemDefs
extends RefCounted

## Three shop tiers, mirroring classic AA: base → mid → secret.


static func all() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	items.append_array(base_shop())
	items.append_array(mid_shop())
	items.append_array(secret_shop())
	return items


static func base_shop() -> Array[Dictionary]:
	return [
		{
			"id": "boots_of_haste",
			"name": "Boots of Haste",
			"shop": "base",
			"cost": 180,
			"blurb": "+35 move speed",
			"stats": {"move_speed": 35.0},
		},
		{
			"id": "iron_buckler",
			"name": "Iron Buckler",
			"shop": "base",
			"cost": 220,
			"blurb": "+80 HP, +3 armor",
			"stats": {"max_hp": 80.0, "armor": 3.0},
		},
		{
			"id": "apprentice_blade",
			"name": "Apprentice Blade",
			"shop": "base",
			"cost": 260,
			"blurb": "+16 attack",
			"stats": {"attack_damage": 16.0},
		},
		{
			"id": "mana_crystal",
			"name": "Mana Crystal",
			"shop": "base",
			"cost": 200,
			"blurb": "+60 mana",
			"stats": {"max_mana": 60.0},
		},
		{
			"id": "healing_salve",
			"name": "Healing Salve",
			"shop": "base",
			"cost": 120,
			"blurb": "Instant heal 180 HP (consumable)",
			"consumable": true,
			"heal": 180.0,
			"stats": {},
		},
	]


static func mid_shop() -> Array[Dictionary]:
	return [
		{
			"id": "burn_shield",
			"name": "Burn Shield",
			"shop": "mid",
			"cost": 650,
			"blurb": "+120 HP, +5 armor — classic mid pickup",
			"stats": {"max_hp": 120.0, "armor": 5.0},
		},
		{
			"id": "rapid_strike",
			"name": "Rapid Strike",
			"shop": "mid",
			"cost": 800,
			"blurb": "+28 attack, +20 move",
			"stats": {"attack_damage": 28.0, "move_speed": 20.0},
		},
		{
			"id": "guardian_force",
			"name": "Guardian Force",
			"shop": "mid",
			"cost": 1100,
			"blurb": "+200 HP, +8 armor",
			"stats": {"max_hp": 200.0, "armor": 8.0},
		},
		{
			"id": "holy_warfare",
			"name": "Holy Warfare",
			"shop": "mid",
			"cost": 1200,
			"blurb": "+40 attack, +80 mana",
			"stats": {"attack_damage": 40.0, "max_mana": 80.0},
		},
	]


static func secret_shop() -> Array[Dictionary]:
	## Unlocked after Mid Boss falls — AA-style late gear fantasy.
	return [
		{
			"id": "overgods_armor",
			"name": "Overgod's Armor",
			"shop": "secret",
			"cost": 2200,
			"blurb": "+350 HP, +14 armor",
			"stats": {"max_hp": 350.0, "armor": 14.0},
		},
		{
			"id": "warlocks_staff",
			"name": "Warlock's Staff",
			"shop": "secret",
			"cost": 2500,
			"blurb": "+70 attack, +120 mana",
			"stats": {"attack_damage": 70.0, "max_mana": 120.0},
		},
		{
			"id": "aether_cleaver",
			"name": "Aether Cleaver",
			"shop": "secret",
			"cost": 2400,
			"blurb": "+55 attack, +40 move — farm machine",
			"stats": {"attack_damage": 55.0, "move_speed": 40.0},
		},
	]


static func by_id(item_id: String) -> Dictionary:
	for item in all():
		if item["id"] == item_id:
			return item
	return {}


static func for_shop(shop_id: String) -> Array[Dictionary]:
	match shop_id:
		"base":
			return base_shop()
		"mid":
			return mid_shop()
		"secret":
			return secret_shop()
		_:
			return all()
