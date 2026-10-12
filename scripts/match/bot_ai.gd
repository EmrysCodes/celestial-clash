extends RefCounted
class_name BotAI

## Smarter AA bot: lane assignment, tiered farming, shopping, focus-fire, duel prep.

const _ItemDefs = preload("res://scripts/data/item_defs.gd")

var unit: CombatUnit
var rng := RandomNumberGenerator.new()
var mode: String = "farm"
var lane_bias: float = 0.0 ## -1 west … +1 east
var think_cd: float = 0.0
var focus_id: int = -1


func _init(p_unit: CombatUnit, bias: float = 0.0) -> void:
	unit = p_unit
	lane_bias = bias
	rng.randomize()


func tick(delta: float, units: Array, match_ref: Node2D) -> Array[Dictionary]:
	var cmds: Array[Dictionary] = []
	if unit == null or not unit.alive:
		return cmds

	think_cd = maxf(0.0, think_cd - delta)
	if match_ref.duel_active:
		return _duel_brain(units)

	var hp_ratio := unit.hp / maxf(1.0, unit.max_hp)
	var mana_ratio := unit.mana / maxf(1.0, unit.max_mana)
	var enemy_hero := _focus_or_nearest_hero(units)
	var camp_target := _best_camp_creep(units, match_ref)
	var shop_id := _desired_shop(match_ref)
	var shop_pos := _shop_pos(match_ref, shop_id)

	## Ascend when possible
	if match_ref.secret_unlocked and not unit.is_god and unit.level >= 8 and think_cd <= 0.0:
		cmds.append({"type": "ascend", "unit_id": unit.unit_id})
		think_cd = 1.0

	if match_ref.duel_timer < 12.0 and hp_ratio < 0.9:
		mode = "fountain"
	elif hp_ratio < 0.28 or (hp_ratio < 0.4 and enemy_hero and unit.global_position.distance_to(enemy_hero.global_position) < 180.0):
		mode = "retreat"
	elif _wants_shop(match_ref) and (hp_ratio > 0.55 or unit.global_position.distance_to(shop_pos) < 400.0):
		mode = "shop"
	elif enemy_hero and _should_fight(enemy_hero, units, hp_ratio):
		mode = "fight"
	elif camp_target:
		mode = "farm"
	else:
		mode = "roam"

	match mode:
		"fountain", "retreat":
			var home := unit.home_position
			cmds.append(InputCommand.move(unit.unit_id, (home - unit.global_position).normalized()))
			if unit.ability_ready(1) and (mana_ratio > 0.2 or hp_ratio < 0.45):
				cmds.append(InputCommand.ability(unit.unit_id, 1))
		"shop":
			cmds.append(InputCommand.move(unit.unit_id, (shop_pos - unit.global_position).normalized()))
			if unit.global_position.distance_to(shop_pos) < 110.0:
				var item := _affordable_item(shop_id, match_ref)
				if not item.is_empty():
					cmds.append(InputCommand.buy(unit.unit_id, item["id"]))
		"fight":
			if enemy_hero:
				_kite_or_chase(cmds, enemy_hero, units, hp_ratio)
		"roam":
			var roam := Vector2(match_ref.MID_POS.x + lane_bias * 420.0, match_ref.MID_POS.y + (200.0 if unit.team == GameSession.TEAM_LIGHT else -200.0))
			cmds.append(InputCommand.move(unit.unit_id, (roam - unit.global_position).normalized()))
		_:
			if camp_target:
				_kite_or_chase(cmds, camp_target, units, hp_ratio)
			elif enemy_hero:
				_kite_or_chase(cmds, enemy_hero, units, hp_ratio)
	return cmds


func _duel_brain(units: Array) -> Array[Dictionary]:
	var cmds: Array[Dictionary] = []
	var foe := _lowest_hp_enemy_hero(units)
	if foe == null:
		foe = _nearest_enemy_hero(units)
	if foe:
		focus_id = foe.unit_id
		_kite_or_chase(cmds, foe, units, unit.hp / maxf(1.0, unit.max_hp))
		## Dump cooldowns in duel
		for slot in 3:
			if unit.ability_ready(slot) and rng.randf() < 0.7:
				cmds.append(InputCommand.ability(unit.unit_id, slot))
	return cmds


func _should_fight(enemy: CombatUnit, units: Array, hp_ratio: float) -> bool:
	var dist := unit.global_position.distance_to(enemy.global_position)
	if dist > 260.0:
		return false
	var allies := _count_nearby_allies(units, 260.0)
	var foes := _count_nearby_enemies(units, 260.0)
	if allies + 1 >= foes and hp_ratio > 0.4:
		return true
	if enemy.hp / maxf(1.0, enemy.max_hp) < 0.35 and hp_ratio > 0.3:
		return true
	return false


func _kite_or_chase(cmds: Array[Dictionary], target: CombatUnit, units: Array, hp_ratio: float) -> void:
	var dist := unit.global_position.distance_to(target.global_position)
	var dir := (target.global_position - unit.global_position).normalized()
	## Ranged kite when low
	if unit.attack_range > 120.0 and hp_ratio < 0.4 and dist < unit.attack_range * 0.7:
		cmds.append(InputCommand.move(unit.unit_id, -dir))
	elif dist > unit.attack_range * 0.88:
		cmds.append(InputCommand.move(unit.unit_id, dir))
	else:
		cmds.append(InputCommand.move(unit.unit_id, Vector2.ZERO))
	cmds.append(InputCommand.attack_target(unit.unit_id, target.unit_id))
	## Abilities: gap close / poke / ult when advantageous
	if unit.ability_ready(0) and dist < 320.0 and rng.randf() < 0.55:
		cmds.append(InputCommand.ability(unit.unit_id, 0))
	if unit.ability_ready(2) and (dist < 200.0 or _count_nearby_enemies(units, 180.0) >= 2) and rng.randf() < 0.45:
		cmds.append(InputCommand.ability(unit.unit_id, 2))
	if unit.ability_ready(1) and hp_ratio < 0.55 and rng.randf() < 0.4:
		cmds.append(InputCommand.ability(unit.unit_id, 1))


func _best_camp_creep(units: Array, match_ref: Node2D) -> CombatUnit:
	var best: CombatUnit = null
	var best_score := -99999.0
	for u in units:
		var c := u as CombatUnit
		if c == null or not c.alive:
			continue
		if c.unit_kind != CombatUnit.Kind.CREEP and c.unit_kind != CombatUnit.Kind.BOSS:
			continue
		if c.unit_kind == CombatUnit.Kind.BOSS and (unit.level < 7 or unit.items.size() < 2):
			continue
		var dist := unit.global_position.distance_to(c.global_position)
		var tier_bonus := 0.0
		match c.display_name:
			"Easy":
				tier_bonus = 55.0 if unit.level < 5 else 15.0
			"Medium":
				tier_bonus = 65.0 if unit.level >= 3 else -25.0
			"Hard":
				tier_bonus = 80.0 if unit.level >= 6 else -50.0
			_:
				if c.unit_kind == CombatUnit.Kind.BOSS:
					tier_bonus = 100.0 if unit.level >= 8 else -120.0
		var side_pen := 0.0
		if unit.team == GameSession.TEAM_LIGHT and c.global_position.y > match_ref.MID_POS.y + 400:
			side_pen = 90.0
		if unit.team == GameSession.TEAM_DARK and c.global_position.y < match_ref.MID_POS.y - 400:
			side_pen = 90.0
		## Prefer assigned lane
		var lane_pen := absf((c.global_position.x - match_ref.MID_POS.x) / 800.0 - lane_bias) * 35.0
		var contested := 0.0
		for o in units:
			var other := o as CombatUnit
			if other and other.alive and other.unit_kind == CombatUnit.Kind.HERO and other.team != unit.team:
				if other.global_position.distance_to(c.global_position) < 220.0:
					contested += 40.0
		var score := tier_bonus - dist * 0.06 - side_pen - lane_pen - contested
		if score > best_score:
			best_score = score
			best = c
	return best


func _desired_shop(match_ref: Node2D) -> String:
	if match_ref.secret_unlocked and unit.gold >= 2000 and unit.items.size() >= 2:
		return "secret"
	if unit.gold >= 650 and unit.level >= 4:
		return "mid"
	return "base"


func _shop_pos(match_ref: Node2D, shop_id: String) -> Vector2:
	if shop_id == "base":
		return match_ref.SHOP_POS["base_light"] if unit.team == GameSession.TEAM_LIGHT else match_ref.SHOP_POS["base_dark"]
	if shop_id == "secret":
		return match_ref.SHOP_POS["secret"]
	return match_ref.SHOP_POS["mid"]


func _wants_shop(match_ref: Node2D) -> bool:
	var shop_id := _desired_shop(match_ref)
	var item := _affordable_item(shop_id, match_ref)
	if item.is_empty() or unit.items.size() >= 6:
		return false
	## Salve when hurt
	if item.get("consumable", false) and unit.hp / unit.max_hp > 0.7:
		return false
	return true


func _affordable_item(shop_id: String, match_ref: Node2D) -> Dictionary:
	if shop_id == "secret" and not match_ref.secret_unlocked:
		return {}
	var options: Array[Dictionary] = []
	for item in _ItemDefs.for_shop(shop_id):
		if int(item["cost"]) <= unit.gold and (item.get("consumable", false) or not unit.items.has(item["id"])):
			options.append(item)
	if options.is_empty():
		return {}
	options.sort_custom(func(a, b): return int(a["cost"]) > int(b["cost"]))
	return options[0]


func _focus_or_nearest_hero(units: Array) -> CombatUnit:
	if focus_id >= 0:
		for u in units:
			var other := u as CombatUnit
			if other and other.alive and other.unit_id == focus_id and other.team != unit.team:
				return other
		focus_id = -1
	return _nearest_enemy_hero(units)


func _nearest_enemy_hero(units: Array) -> CombatUnit:
	var best: CombatUnit = null
	var best_d := 99999.0
	for u in units:
		var other := u as CombatUnit
		if other == null or not other.alive or other.team == unit.team or other.unit_kind != CombatUnit.Kind.HERO:
			continue
		var d := unit.global_position.distance_to(other.global_position)
		if d < best_d:
			best_d = d
			best = other
	return best


func _lowest_hp_enemy_hero(units: Array) -> CombatUnit:
	var best: CombatUnit = null
	var best_hp := 999999.0
	for u in units:
		var other := u as CombatUnit
		if other == null or not other.alive or other.team == unit.team or other.unit_kind != CombatUnit.Kind.HERO:
			continue
		if other.global_position.distance_to(unit.global_position) > 420.0:
			continue
		if other.hp < best_hp:
			best_hp = other.hp
			best = other
	return best


func _count_nearby_allies(units: Array, radius: float) -> int:
	var n := 0
	for u in units:
		var other := u as CombatUnit
		if other and other.alive and other != unit and other.team == unit.team and other.unit_kind == CombatUnit.Kind.HERO:
			if unit.global_position.distance_to(other.global_position) <= radius:
				n += 1
	return n


func _count_nearby_enemies(units: Array, radius: float) -> int:
	var n := 0
	for u in units:
		var other := u as CombatUnit
		if other and other.alive and other.team != unit.team and other.unit_kind == CombatUnit.Kind.HERO:
			if unit.global_position.distance_to(other.global_position) <= radius:
				n += 1
	return n
