extends Node2D

## Authoritative local match — Angel Arena formula:
## team lives, scheduled duels, tiered camps, mid boss → god + secret shop.

const ARENA_SIZE := Vector2(3600, 3600)
const MID_POS := Vector2(1800, 1800)
const DUEL_INTERVAL := 80.0
const DUEL_DURATION := 30.0
const DUEL_WARN := 10.0

signal lives_changed(light_lives: int, dark_lives: int)
signal match_over(winning_team: int)
signal unit_feed(message: String)
signal duel_state_changed(state: String, seconds: float)
signal shop_unlocks_changed(secret_open: bool)
signal boss_hp_changed(current: float, maximum: float, alive: bool)

@onready var world: Node2D = $World
@onready var units_root: Node2D = $World/Units
@onready var camera: Camera2D = $Camera2D
@onready var hud: CanvasLayer = $HUD

var units: Array[CombatUnit] = []
var bots: Array[BotAI] = []
var player_unit: CombatUnit = null
var next_unit_id: int = 1
var light_lives: int = GameSession.LIVES_PER_TEAM
var dark_lives: int = GameSession.LIVES_PER_TEAM
var ended: bool = false
var shop_open: bool = false
var active_shop: String = "base"
var secret_unlocked: bool = false
var mid_boss: CombatUnit = null
var mid_boss_dead: bool = false

var duel_timer: float = DUEL_INTERVAL
var duel_active: bool = false
var duel_time_left: float = 0.0
var duel_deaths_light: int = 0
var duel_deaths_dark: int = 0

var camp_states: Dictionary = {} ## camp_id -> {timer, alive_ids}

var hero_scene: PackedScene = preload("res://scenes/units/hero.tscn")
var creep_scene: PackedScene = preload("res://scenes/units/creep.tscn")
const _CampDefs = preload("res://scripts/data/camp_defs.gd")
const _HeroDefs = preload("res://scripts/data/hero_defs.gd")
const _ItemDefs = preload("res://scripts/data/item_defs.gd")

const SHOP_POS := {
	"base_light": Vector2(1800, 260),
	"base_dark": Vector2(1800, 3340),
	"mid": Vector2(2040, 1800),
	"secret": Vector2(1560, 1800),
}


func _ready() -> void:
	NetBridge.command_received.connect(_on_command)
	_build_arena_visuals()
	_init_camps()
	_spawn_match()
	hud.setup(self)
	lives_changed.emit(light_lives, dark_lives)
	duel_state_changed.emit("idle", duel_timer)
	unit_feed.emit("Farm camps. Survive. Win duels. Drain their lives.")


func _process(delta: float) -> void:
	if ended:
		return
	_tick_duel(delta)
	if not duel_active:
		_tick_bots(delta)
		_tick_camps(delta)
		_tick_creep_ai(delta)
	else:
		_tick_bots(delta) ## bots still fight in duel
	_tick_respawns()
	_tick_fountains(delta)
	_emit_boss_hp()
	if player_unit and player_unit.alive:
		camera.global_position = camera.global_position.lerp(player_unit.global_position, 1.0 - pow(0.001, delta))
	elif player_unit:
		camera.global_position = camera.global_position.lerp(player_unit.home_position, 1.0 - pow(0.001, delta))


func _emit_boss_hp() -> void:
	if mid_boss and is_instance_valid(mid_boss) and mid_boss.alive:
		boss_hp_changed.emit(mid_boss.hp, mid_boss.max_hp, true)
	else:
		boss_hp_changed.emit(0.0, 1.0, false)


func _build_arena_visuals() -> void:
	ArenaBuilder.build(world, ARENA_SIZE, MID_POS, SHOP_POS)


func _init_camps() -> void:
	for camp in _CampDefs.camps():
		camp_states[camp["id"]] = {"timer": 0.0, "def": camp}
		_spawn_camp(camp)


func _spawn_camp(camp: Dictionary) -> void:
	var tier: String = camp["tier"]
	var count: int = int(camp["count"])
	for i in count:
		var offset := Vector2(randf_range(-30, 30), randf_range(-30, 30))
		_spawn_creep(tier, camp["pos"] + offset, camp["id"])


func _spawn_match() -> void:
	## 4v4 — player on Seraphim + 3 ally bots vs 4 Ashen bots
	var player_def: Dictionary = _HeroDefs.by_id(GameSession.selected_hero_id)
	var used: Array = [player_def["id"]]
	var light_slots := [
		Vector2(1680, 280), Vector2(1800, 240), Vector2(1920, 280), Vector2(1800, 340)
	]
	var dark_slots := [
		Vector2(1680, 3320), Vector2(1800, 3360), Vector2(1920, 3320), Vector2(1800, 3260)
	]
	player_unit = _spawn_hero(player_def, GameSession.TEAM_LIGHT, light_slots[1], false, 0.0)

	var biases := [-0.85, -0.25, 0.25, 0.85]
	for i in GameSession.TEAM_SIZE:
		if i == 1:
			continue ## player slot
		var def := _pick_other_hero(used)
		used.append(def["id"])
		_spawn_hero(def, GameSession.TEAM_LIGHT, light_slots[i], true, biases[i])

	used = [player_def["id"]]
	for i in GameSession.TEAM_SIZE:
		var def2 := _pick_other_hero(used)
		used.append(def2["id"])
		_spawn_hero(def2, GameSession.TEAM_DARK, dark_slots[i], true, biases[i])

	_spawn_mid_boss()
	camera.global_position = player_unit.global_position
	camera.zoom = Vector2(0.7, 0.7)
	camera.make_current()


func _spawn_mid_boss() -> void:
	if mid_boss_dead:
		return
	mid_boss = creep_scene.instantiate() as CombatUnit
	units_root.add_child(mid_boss)
	## North of duel ring
	mid_boss.configure_creep("boss", next_unit_id, Vector2(MID_POS.x, MID_POS.y - 420), "mid_boss")
	next_unit_id += 1
	mid_boss.died.connect(_on_unit_died)
	units.append(mid_boss)


func _pick_other_hero(exclude_ids: Array = []) -> Dictionary:
	var pool: Array[Dictionary] = []
	for h in _HeroDefs.all():
		if exclude_ids.has(h["id"]):
			continue
		pool.append(h)
	## Allow duplicates once roster exhausted (4v4 > unique heroes)
	if pool.is_empty():
		pool.append_array(_HeroDefs.all())
	return pool[randi() % pool.size()]


func _spawn_hero(def: Dictionary, team: int, pos: Vector2, is_bot: bool, lane_bias: float = 0.0) -> CombatUnit:
	var hero := hero_scene.instantiate() as CombatUnit
	units_root.add_child(hero)
	hero.configure_hero(def, team, next_unit_id)
	next_unit_id += 1
	hero.global_position = pos
	hero.home_position = pos
	hero.died.connect(_on_unit_died)
	units.append(hero)
	if is_bot:
		bots.append(BotAI.new(hero, lane_bias))
	return hero


func _spawn_creep(tier: String, pos: Vector2, camp_id: String) -> void:
	var creep := creep_scene.instantiate() as CombatUnit
	units_root.add_child(creep)
	creep.configure_creep(tier, next_unit_id, pos, camp_id)
	next_unit_id += 1
	creep.died.connect(_on_unit_died)
	units.append(creep)


func _tick_camps(delta: float) -> void:
	for camp_id in camp_states.keys():
		var state: Dictionary = camp_states[camp_id]
		var camp: Dictionary = state["def"]
		var alive := 0
		for u in units:
			if u.camp_id == camp_id and u.alive:
				alive += 1
		if alive == 0:
			state["timer"] = float(state.get("timer", 0.0)) - delta
			if float(state["timer"]) <= 0.0:
				_spawn_camp(camp)
				state["timer"] = float(camp["respawn"])
		else:
			state["timer"] = float(camp["respawn"])
		camp_states[camp_id] = state


func _tick_creep_ai(_delta: float) -> void:
	for u in units:
		if u.unit_kind == CombatUnit.Kind.HERO or not u.alive:
			continue
		if duel_active:
			u.set_move_dir(Vector2.ZERO)
			continue
		var enemy := u._nearest_hostile(units, 240.0 if u.unit_kind != CombatUnit.Kind.BOSS else 320.0)
		if enemy:
			var dir := (enemy.global_position - u.global_position).normalized()
			if u.global_position.distance_to(enemy.global_position) > u.attack_range:
				u.set_move_dir(dir)
			else:
				u.set_move_dir(Vector2.ZERO)
				u.try_attack(units)
		else:
			## leash back to camp
			var home := u.home_position
			if u.global_position.distance_to(home) > 40.0:
				u.set_move_dir((home - u.global_position).normalized())
			else:
				u.set_move_dir(Vector2.ZERO)


func _tick_bots(delta: float) -> void:
	for bot in bots:
		for cmd in bot.tick(delta, units, self):
			NetBridge.submit_command(cmd)


func _tick_respawns() -> void:
	if duel_active:
		return
	for u in units:
		if u.unit_kind == CombatUnit.Kind.HERO and not u.alive and u.respawn_timer <= 0.0:
			u.respawn()
			unit_feed.emit("%s returned to fountain." % u.display_name)


func _tick_fountains(delta: float) -> void:
	if duel_active:
		return
	for u in units:
		if u.unit_kind != CombatUnit.Kind.HERO or not u.alive:
			continue
		var fountain := Vector2(MID_POS.x, 180) if u.team == GameSession.TEAM_LIGHT else Vector2(MID_POS.x, ARENA_SIZE.y - 180)
		if u.global_position.distance_to(fountain) < 160.0:
			u.heal(70.0 * delta)
			u.mana = minf(u.max_mana, u.mana + 50.0 * delta)


func _tick_duel(delta: float) -> void:
	if duel_active:
		duel_time_left -= delta
		duel_state_changed.emit("active", duel_time_left)
		if duel_time_left <= 0.0:
			_end_duel()
		return

	duel_timer -= delta
	if duel_timer <= DUEL_WARN and duel_timer + delta > DUEL_WARN:
		unit_feed.emit("Duel in %d seconds! Get ready." % int(DUEL_WARN))
	duel_state_changed.emit("idle", duel_timer)
	if duel_timer <= 0.0:
		_start_duel()


func _start_duel() -> void:
	duel_active = true
	duel_time_left = DUEL_DURATION
	duel_deaths_light = 0
	duel_deaths_dark = 0
	shop_open = false
	hud.set_shop_open(false)

	var slots_light := [
		Vector2(1680, 1680), Vector2(1740, 1760), Vector2(1860, 1680), Vector2(1800, 1840)
	]
	var slots_dark := [
		Vector2(1920, 1680), Vector2(1860, 1760), Vector2(1740, 1920), Vector2(1800, 1920)
	]
	var li := 0
	var di := 0
	for u in units:
		if u.unit_kind != CombatUnit.Kind.HERO:
			continue
		if not u.alive:
			u.respawn()
		u.pre_duel_position = u.global_position
		u.duel_locked = true
		u.hp = u.max_hp
		u.mana = u.max_mana
		if u.team == GameSession.TEAM_LIGHT:
			u.global_position = slots_light[mini(li, slots_light.size() - 1)]
			li += 1
		else:
			u.global_position = slots_dark[mini(di, slots_dark.size() - 1)]
			di += 1
		u.set_move_dir(Vector2.ZERO)

	unit_feed.emit("DUEL! Fight until the bell — losers lose %d lives!" % GameSession.DUEL_LIFE_PENALTY)
	duel_state_changed.emit("active", duel_time_left)
	NetBridge.broadcast_event({"type": "duel_start"})


func _end_duel() -> void:
	duel_active = false
	duel_timer = DUEL_INTERVAL

	var light_alive := 0
	var dark_alive := 0
	for u in units:
		if u.unit_kind != CombatUnit.Kind.HERO:
			continue
		if u.alive:
			if u.team == GameSession.TEAM_LIGHT:
				light_alive += 1
			else:
				dark_alive += 1
		u.duel_locked = false
		if u.alive:
			u.global_position = u.pre_duel_position
		u.set_move_dir(Vector2.ZERO)

	var winner := -1
	if light_alive > dark_alive:
		winner = GameSession.TEAM_LIGHT
	elif dark_alive > light_alive:
		winner = GameSession.TEAM_DARK
	elif duel_deaths_dark > duel_deaths_light:
		winner = GameSession.TEAM_LIGHT
	elif duel_deaths_light > duel_deaths_dark:
		winner = GameSession.TEAM_DARK

	if winner == -1:
		unit_feed.emit("Duel draw — no lives lost.")
	else:
		var loser := GameSession.TEAM_DARK if winner == GameSession.TEAM_LIGHT else GameSession.TEAM_LIGHT
		_lose_lives(loser, GameSession.DUEL_LIFE_PENALTY, "duel")
		for u in units:
			if u.unit_kind == CombatUnit.Kind.HERO and u.team == winner and u.alive:
				u.add_gold(350)
				u.add_xp(120.0)
		unit_feed.emit("%s win the duel! (+gold/XP) %s lose %d lives." % [
			GameSession.team_name(winner), GameSession.team_name(loser), GameSession.DUEL_LIFE_PENALTY
		])

	duel_state_changed.emit("idle", duel_timer)
	NetBridge.broadcast_event({"type": "duel_end", "winner": winner})


func _lose_lives(team: int, amount: int, reason: String) -> void:
	if team == GameSession.TEAM_LIGHT:
		light_lives = maxi(0, light_lives - amount)
	else:
		dark_lives = maxi(0, dark_lives - amount)
	lives_changed.emit(light_lives, dark_lives)
	NetBridge.broadcast_event({"type": "lives", "team": team, "amount": amount, "reason": reason})
	_check_win()


func _unhandled_input(event: InputEvent) -> void:
	if ended or player_unit == null or not player_unit.alive:
		return
	var tapped := false
	var screen_pos := Vector2.ZERO
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			tapped = true
			screen_pos = st.position
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			tapped = true
			screen_pos = mb.position
	if not tapped:
		return
	var world_pos := _screen_to_world(screen_pos)
	_handle_world_tap(world_pos)
	get_viewport().set_input_as_handled()


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var canvas := get_viewport().get_canvas_transform()
	return canvas.affine_inverse() * screen_pos


func _handle_world_tap(world_pos: Vector2) -> void:
	## Priority: enemy → attack focus; shop/fountain → interact; else move-to.
	var enemy := _unit_at(world_pos, 42.0, true)
	if enemy:
		player_submit(InputCommand.attack_target(player_unit.unit_id, enemy.unit_id))
		_spawn_world_marker("res://assets/sprites/fx/attack_marker.png", enemy.global_position)
		return
	var interact_id := _interactable_at(world_pos)
	if interact_id != "":
		player_submit(InputCommand.interact(player_unit.unit_id, interact_id))
		_spawn_world_marker("res://assets/sprites/fx/interact_marker.png", world_pos)
		return
	player_submit(InputCommand.move_to(player_unit.unit_id, world_pos))
	_spawn_world_marker("res://assets/sprites/fx/move_marker.png", world_pos)


func _unit_at(world_pos: Vector2, radius: float, hostile_only: bool) -> CombatUnit:
	var best: CombatUnit = null
	var best_d := radius
	for u in units:
		if u == null or not u.alive:
			continue
		if hostile_only and (player_unit == null or not player_unit._is_hostile(u)):
			continue
		var d := u.global_position.distance_to(world_pos)
		if d < best_d:
			best_d = d
			best = u
	return best


func _interactable_at(world_pos: Vector2) -> String:
	var best := ""
	var best_d := 70.0
	var spots := {
		"shop_base": SHOP_POS["base_light"] if player_unit.team == GameSession.TEAM_LIGHT else SHOP_POS["base_dark"],
		"shop_mid": SHOP_POS["mid"],
		"shop_secret": SHOP_POS["secret"],
		"fountain": Vector2(MID_POS.x, 180) if player_unit.team == GameSession.TEAM_LIGHT else Vector2(MID_POS.x, ARENA_SIZE.y - 180),
	}
	for id in spots.keys():
		var d: float = world_pos.distance_to(spots[id])
		if d < best_d:
			best_d = d
			best = id
	return best


func _spawn_world_marker(tex_path: String, pos: Vector2) -> void:
	var spr := Sprite2D.new()
	spr.texture = load(tex_path)
	spr.global_position = pos
	spr.z_index = 15
	world.add_child(spr)
	var tw := spr.create_tween()
	tw.tween_property(spr, "modulate:a", 0.0, 0.7)
	tw.parallel().tween_property(spr, "scale", Vector2(1.4, 1.4), 0.7)
	tw.tween_callback(spr.queue_free)


func _on_command(command: Dictionary) -> void:
	if ended:
		return
	var uid: int = int(command.get("unit_id", -1))
	var unit := _unit_by_id(uid)
	if unit == null:
		return
	match String(command.get("type", "")):
		InputCommand.MOVE:
			unit.set_move_dir(InputCommand.dir_from(command))
		InputCommand.MOVE_TO:
			unit.set_move_to(InputCommand.pos_from(command))
		InputCommand.ATTACK:
			unit.try_attack(units)
		InputCommand.ATTACK_TARGET:
			var target := _unit_by_id(int(command.get("target_id", -1)))
			if target:
				unit.set_attack_focus(target)
		InputCommand.INTERACT:
			_handle_interact(unit, String(command.get("interact_id", "")))
		InputCommand.ABILITY:
			var slot := int(command.get("slot", 0))
			if unit.cast_ability(slot, units):
				_play_ability_fx(unit, slot)
				unit_feed.emit("%s used ability %d" % [unit.display_name, slot + 1])
		InputCommand.BUY:
			_try_buy(unit, String(command.get("item_id", "")))
		InputCommand.SHOP_TOGGLE:
			if unit == player_unit:
				_toggle_shop_for_player()
		"ascend":
			_try_ascend(unit)


func _handle_interact(unit: CombatUnit, interact_id: String) -> void:
	if unit != player_unit:
		return
	if interact_id.begins_with("shop"):
		## Walk to shop if far, else toggle.
		var shop_key := "base"
		if interact_id == "shop_mid":
			shop_key = "mid"
		elif interact_id == "shop_secret":
			shop_key = "secret"
		var dest: Vector2 = SHOP_POS["base_light"] if unit.team == GameSession.TEAM_LIGHT else SHOP_POS["base_dark"]
		if shop_key == "mid":
			dest = SHOP_POS["mid"]
		elif shop_key == "secret":
			dest = SHOP_POS["secret"]
		if unit.global_position.distance_to(dest) > 120.0:
			unit.set_move_to(dest)
			unit_feed.emit("Moving to %s shop…" % shop_key)
		else:
			active_shop = shop_key
			_toggle_shop_for_player()
	elif interact_id == "fountain":
		var fountain := Vector2(MID_POS.x, 180) if unit.team == GameSession.TEAM_LIGHT else Vector2(MID_POS.x, ARENA_SIZE.y - 180)
		unit.set_move_to(fountain)
		unit_feed.emit("Returning to fountain.")


func _play_ability_fx(unit: CombatUnit, slot: int) -> void:
	var abilities: Array = unit.hero_def.get("abilities", [])
	if slot < 0 or slot >= abilities.size():
		return
	FxPlayer.ability(world, unit.global_position, String(abilities[slot]))


func _toggle_shop_for_player() -> void:
	var shop_id := nearest_shop_for(player_unit)
	if shop_id == "":
		unit_feed.emit("Move to Base / Mid / Secret shop.")
		shop_open = false
		hud.set_shop_open(false)
		return
	if shop_id == "secret" and not secret_unlocked:
		unit_feed.emit("Secret Shop locked — slay the Mid Boss first.")
		return
	active_shop = shop_id
	shop_open = not shop_open
	hud.set_shop_open(shop_open)
	hud.refresh_shop()


func nearest_shop_for(unit: CombatUnit) -> String:
	if unit == null or not unit.alive:
		return ""
	var best := ""
	var best_d := 130.0
	var candidates := {
		"base": SHOP_POS["base_light"] if unit.team == GameSession.TEAM_LIGHT else SHOP_POS["base_dark"],
		"mid": SHOP_POS["mid"],
		"secret": SHOP_POS["secret"],
	}
	for shop_id in candidates.keys():
		var d := unit.global_position.distance_to(candidates[shop_id])
		if d < best_d:
			best_d = d
			best = shop_id
	return best


func _try_buy(unit: CombatUnit, item_id: String) -> void:
	var item: Dictionary = _ItemDefs.by_id(item_id)
	if item.is_empty():
		return
	var shop_needed: String = String(item.get("shop", "base"))
	if shop_needed == "secret" and not secret_unlocked:
		if unit == player_unit:
			unit_feed.emit("Secret Shop still sealed.")
		return
	var at := nearest_shop_for(unit)
	## Allow buy if standing at correct tier shop, or base can sell base, mid sells mid, etc.
	if at != shop_needed:
		if unit == player_unit:
			unit_feed.emit("Stand at the %s shop to buy that." % shop_needed)
		return
	if unit.buy_item(item):
		unit_feed.emit("%s bought %s" % [unit.display_name, item.get("name", "?")])
		hud.refresh_shop()


func _try_ascend(unit: CombatUnit) -> void:
	if not mid_boss_dead or unit.is_god or unit.unit_kind != CombatUnit.Kind.HERO:
		return
	if unit.level < 8:
		if unit == player_unit:
			unit_feed.emit("Need level 8 to Ascend.")
		return
	unit.ascend_to_god()
	FxPlayer.play(world, "res://assets/sprites/fx/ascend_ring.png", unit.global_position, 80, 12.0, 1.4)
	FxPlayer.particles(world, unit.global_position, "ascend", 0.9)
	unit_feed.emit("%s ASCENDED into %s!" % [_HeroDefs.by_id(unit.hero_def["id"])["name"], unit.display_name])


func _on_unit_died(unit: CombatUnit, killer: CombatUnit) -> void:
	if unit.unit_kind == CombatUnit.Kind.CREEP or unit.unit_kind == CombatUnit.Kind.BOSS:
		_on_creep_or_boss_died(unit, killer)
		return

	## Hero death → team loses a life (classic AA)
	if not duel_active:
		_lose_lives(unit.team, 1, "death")
		unit_feed.emit("%s fell (−1 life). %s / %s lives remain." % [
			unit.display_name, str(light_lives), str(dark_lives)
		])
	else:
		if unit.team == GameSession.TEAM_LIGHT:
			duel_deaths_light += 1
		else:
			duel_deaths_dark += 1
		unit_feed.emit("%s eliminated in the duel!" % unit.display_name)

	if killer and killer.unit_kind == CombatUnit.Kind.HERO and killer.team != unit.team:
		killer.add_gold(180 if not duel_active else 100)
		killer.add_xp(70.0)


func _on_creep_or_boss_died(unit: CombatUnit, killer: CombatUnit) -> void:
	FxPlayer.play(world, "res://assets/sprites/fx/death_puff.png", unit.global_position, 64, 12.0, 1.0)
	FxPlayer.particles(world, unit.global_position, "hit", 0.4)
	var awarding := killer
	if awarding == null or awarding.unit_kind != CombatUnit.Kind.HERO:
		awarding = unit.last_attacker
	if awarding and awarding.unit_kind == CombatUnit.Kind.HERO:
		awarding.add_gold(unit.bounty_gold)
		awarding.add_xp(unit.bounty_xp)
		FxPlayer.gold_popup(world, unit.global_position, unit.bounty_gold)
		for u in units:
			if u != awarding and u.alive and u.team == awarding.team and u.unit_kind == CombatUnit.Kind.HERO:
				if u.global_position.distance_to(unit.global_position) < 300.0:
					u.add_xp(unit.bounty_xp * 0.4)
					u.add_gold(int(unit.bounty_gold * 0.3))

	if unit.unit_kind == CombatUnit.Kind.BOSS:
		mid_boss_dead = true
		mid_boss = null
		secret_unlocked = true
		shop_unlocks_changed.emit(true)
		var secret_spr := world.get_node_or_null("SecretShop") as Sprite2D
		if secret_spr:
			secret_spr.modulate = Color(1.2, 1.0, 0.5, 1)
		unit_feed.emit("MID BOSS DOWN! Secret Shop open. Heroes may Ascend (level 8+).")
		if awarding and awarding.unit_kind == CombatUnit.Kind.HERO:
			awarding.add_gold(400)
			if awarding.level >= 8:
				awarding.ascend_to_god()
				unit_feed.emit("%s claims godhood from the Mid Boss!" % awarding.display_name)

	unit.queue_free()
	units.erase(unit)


func _check_win() -> void:
	if light_lives <= 0:
		_finish(GameSession.TEAM_DARK)
	elif dark_lives <= 0:
		_finish(GameSession.TEAM_LIGHT)


func _finish(winning_team: int) -> void:
	if ended:
		return
	ended = true
	duel_active = false
	GameSession.last_result = {
		"winner": winning_team,
		"light_lives": light_lives,
		"dark_lives": dark_lives,
		"hero": GameSession.selected_hero_id,
	}
	match_over.emit(winning_team)
	unit_feed.emit("%s victory — the other side is out of lives!" % GameSession.team_name(winning_team))


func _unit_by_id(uid: int) -> CombatUnit:
	for u in units:
		if u.unit_id == uid:
			return u
	return null


func player_submit(command: Dictionary) -> void:
	NetBridge.submit_command(command)


func get_player() -> CombatUnit:
	return player_unit


func get_active_shop() -> String:
	return active_shop
