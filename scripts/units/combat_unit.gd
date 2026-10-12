extends CharacterBody2D
class_name CombatUnit

signal died(unit: CombatUnit, killer: CombatUnit)
signal damaged(unit: CombatUnit, amount: float, source: CombatUnit)
signal stats_changed(unit: CombatUnit)
signal ascended(unit: CombatUnit)

enum Kind { HERO, CREEP, BOSS }

@export var unit_kind: Kind = Kind.HERO
@export var team: int = 0
@export var display_name: String = "Unit"

var unit_id: int = 0
var max_hp: float = 100.0
var hp: float = 100.0
var max_mana: float = 100.0
var mana: float = 100.0
var armor: float = 0.0
var move_speed: float = 180.0
var attack_damage: float = 20.0
var attack_range: float = 70.0
var attack_cooldown: float = 0.8
var gold: int = 0
var level: int = 1
var xp: float = 0.0
var xp_to_level: float = 100.0
var strength: float = 10.0
var agility: float = 10.0
var intelligence: float = 10.0

var move_dir: Vector2 = Vector2.ZERO
var move_target: Vector2 = Vector2.INF
var has_move_target: bool = false
var attack_focus: CombatUnit = null
var attack_timer: float = 0.0
var ability_cds: Array[float] = [0.0, 0.0, 0.0]
var status_slow: float = 0.0
var status_root: float = 0.0
var status_reflect: float = 0.0
var status_power: float = 0.0
var status_armor_buff: float = 0.0
var alive: bool = true
var respawn_timer: float = 0.0
var home_position: Vector2 = Vector2.ZERO
var hero_def: Dictionary = {}
var items: Array[String] = []
var last_attacker: CombatUnit = null
var is_god: bool = false
var camp_id: String = ""
var bounty_gold: int = 0
var bounty_xp: float = 0.0
var duel_locked: bool = false
var pre_duel_position: Vector2 = Vector2.ZERO
var anim_busy: float = 0.0
var sheet_path: String = ""

@onready var sprite: Node2D = $Sprite2D
@onready var hp_bar: ProgressBar = $HpBar
@onready var name_label: Label = $NameLabel
@onready var collision: CollisionShape2D = $CollisionShape2D

const _CampDefs = preload("res://scripts/data/camp_defs.gd")
const _HeroDefs = preload("res://scripts/data/hero_defs.gd")


func _ready() -> void:
	_update_bars()


func configure_hero(def: Dictionary, p_team: int, p_id: int) -> void:
	hero_def = def
	unit_kind = Kind.HERO
	team = p_team
	unit_id = p_id
	display_name = def["name"]
	max_hp = def["max_hp"]
	hp = max_hp
	max_mana = def["max_mana"]
	mana = max_mana
	armor = def["armor"]
	move_speed = def["move_speed"]
	attack_damage = def["attack_damage"]
	attack_range = def["attack_range"]
	attack_cooldown = def["attack_cooldown"]
	strength = float(def.get("str", 10))
	agility = float(def.get("agi", 10))
	intelligence = float(def.get("intel", 10))
	gold = 350 ## AA starts you able to buy a couple base items
	level = 1
	xp = 0.0
	xp_to_level = 100.0
	is_god = false
	sheet_path = "res://assets/sprites/heroes/%s_sheet.png" % String(def["id"])
	_setup_sprite_frames(sheet_path, 128, 128, true)
	if sprite:
		sprite.scale = Vector2(0.72, 0.72)
	if name_label:
		name_label.text = display_name
	_tint_team()
	_update_bars()


func configure_creep(tier: String, p_id: int, pos: Vector2, p_camp_id: String = "") -> void:
	var stats: Dictionary = _CampDefs.tier_stats(tier)
	unit_kind = Kind.BOSS if tier == "boss" else Kind.CREEP
	team = -1 ## neutral camps (hostile to all heroes)
	unit_id = p_id
	camp_id = p_camp_id
	display_name = "Mid Boss" if tier == "boss" else tier.capitalize()
	max_hp = float(stats["hp"])
	hp = max_hp
	max_mana = 0.0
	mana = 0.0
	armor = float(stats["armor"])
	move_speed = float(stats["speed"])
	attack_damage = float(stats["dmg"])
	attack_range = 60.0 if tier != "boss" else 90.0
	attack_cooldown = 1.05 if tier != "boss" else 1.2
	bounty_gold = int(stats["gold"])
	bounty_xp = float(stats["xp"])
	home_position = pos
	global_position = pos
	var creep_key := "elite" if tier in ["hard", "boss"] else ("light" if tier == "easy" else "dark")
	sheet_path = "res://assets/sprites/creeps/%s_sheet.png" % creep_key
	_setup_sprite_frames(sheet_path, 80, 80, false)
	if sprite:
		if tier == "boss":
			sprite.scale = Vector2(1.45, 1.45)
		elif tier == "hard":
			sprite.scale = Vector2(1.05, 1.05)
		else:
			sprite.scale = Vector2(0.8, 0.8)
	if name_label:
		name_label.visible = tier in ["hard", "boss"]
		name_label.text = display_name
	_update_bars()


func _setup_sprite_frames(path: String, fw: int, fh: int, has_attack: bool) -> void:
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		# fallback single sprite
		if sprite is Sprite2D:
			(sprite as Sprite2D).texture = load(hero_def.get("sprite", "res://assets/sprites/hero_seraph.png"))
		return
	var anim := sprite as AnimatedSprite2D
	if anim == null:
		# Replace Sprite2D with AnimatedSprite2D at runtime if scene still has Sprite2D
		var old := sprite
		anim = AnimatedSprite2D.new()
		anim.name = "Sprite2D"
		anim.z_index = old.z_index
		anim.scale = old.scale
		old.replace_by(anim)
		old.queue_free()
		sprite = anim
	var frames := SpriteFrames.new()
	_add_sheet_anim(frames, tex, "idle", 0, 4, fw, fh, 7.0, true)
	_add_sheet_anim(frames, tex, "walk", 1, 4, fw, fh, 11.0, true)
	if has_attack:
		_add_sheet_anim(frames, tex, "attack", 2, 4, fw, fh, 14.0, false)
	else:
		_add_sheet_anim(frames, tex, "attack", 1, 4, fw, fh, 12.0, false)
	anim.sprite_frames = frames
	anim.play("idle")


func _add_sheet_anim(frames: SpriteFrames, tex: Texture2D, anim_name: String, row: int, count: int, fw: int, fh: int, fps: float, loop: bool) -> void:
	if frames.has_animation(anim_name):
		frames.remove_animation(anim_name)
	frames.add_animation(anim_name)
	frames.set_animation_loop(anim_name, loop)
	frames.set_animation_speed(anim_name, fps)
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * fw, row * fh, fw, fh)
		frames.add_frame(anim_name, at)


func ascend_to_god() -> void:
	if is_god or unit_kind != Kind.HERO or hero_def.is_empty():
		return
	is_god = true
	var god_name: String = String(hero_def.get("god_name", "God"))
	display_name = god_name
	max_hp *= 1.55
	hp = max_hp
	max_mana *= 1.35
	mana = max_mana
	attack_damage *= 1.45
	armor += 8.0
	move_speed += 25.0
	strength *= 1.4
	agility *= 1.4
	intelligence *= 1.4
	if name_label:
		name_label.text = display_name
	if sprite:
		sprite.scale = Vector2(0.95, 0.95)
		sprite.modulate = Color(1.25, 1.15, 0.75, 1)
	ascended.emit(self)
	stats_changed.emit(self)


func _tint_team() -> void:
	if sprite == null or unit_kind != Kind.HERO:
		return
	sprite.modulate = Color(1.05, 1.05, 1.05, 1) if team == GameSession.TEAM_LIGHT else Color(1.08, 0.92, 0.92, 1)


func _physics_process(delta: float) -> void:
	if not alive:
		respawn_timer -= delta
		visible = false
		collision.set_deferred("disabled", true)
		return
	visible = true
	collision.set_deferred("disabled", false)

	attack_timer = maxf(0.0, attack_timer - delta)
	anim_busy = maxf(0.0, anim_busy - delta)
	status_slow = maxf(0.0, status_slow - delta)
	status_root = maxf(0.0, status_root - delta)
	status_reflect = maxf(0.0, status_reflect - delta)
	status_power = maxf(0.0, status_power - delta)
	status_armor_buff = maxf(0.0, status_armor_buff - delta)
	for i in ability_cds.size():
		ability_cds[i] = maxf(0.0, ability_cds[i] - delta)

	if unit_kind == Kind.HERO:
		mana = minf(max_mana, mana + 10.0 * delta)

	_resolve_orders(delta)

	var speed := move_speed
	if status_slow > 0.0:
		speed *= 0.55
	if status_root > 0.0:
		speed = 0.0
		move_dir = Vector2.ZERO

	velocity = move_dir.limit_length(1.0) * speed
	move_and_slide()
	if not duel_locked:
		_clamp_to_arena()
	else:
		_clamp_to_duel_ring()
	_update_facing()
	_update_animation()
	_update_bars()


func _resolve_orders(_delta: float) -> void:
	## Attack-focus overrides: chase then strike.
	if attack_focus != null:
		if not is_instance_valid(attack_focus) or not attack_focus.alive:
			attack_focus = null
		else:
			var dist := global_position.distance_to(attack_focus.global_position)
			if dist > attack_range * 0.92:
				move_dir = (attack_focus.global_position - global_position).normalized()
				has_move_target = false
			else:
				move_dir = Vector2.ZERO
				has_move_target = false
				try_attack_unit(attack_focus)
			return

	if has_move_target:
		var to := move_target - global_position
		if to.length() <= 12.0:
			has_move_target = false
			move_dir = Vector2.ZERO
		else:
			move_dir = to.normalized()


func _update_facing() -> void:
	if sprite == null:
		return
	if absf(velocity.x) > 8.0:
		sprite.flip_h = velocity.x < 0.0


func _update_animation() -> void:
	var anim := sprite as AnimatedSprite2D
	if anim == null or anim.sprite_frames == null:
		return
	if anim_busy > 0.0:
		return
	var next := "idle"
	if velocity.length() > 12.0:
		next = "walk"
	if anim.animation != next:
		anim.play(next)


func _clamp_to_arena() -> void:
	global_position.x = clampf(global_position.x, 80.0, 3520.0)
	global_position.y = clampf(global_position.y, 80.0, 3520.0)


func _clamp_to_duel_ring() -> void:
	global_position.x = clampf(global_position.x, 1560.0, 2040.0)
	global_position.y = clampf(global_position.y, 1600.0, 2000.0)


func clear_orders() -> void:
	has_move_target = false
	attack_focus = null


func set_move_dir(dir: Vector2) -> void:
	if not alive:
		return
	## Manual stick/keyboard clears click orders while active.
	if dir.length() > 0.08:
		clear_orders()
	move_dir = dir


func set_move_to(pos: Vector2) -> void:
	if not alive:
		return
	attack_focus = null
	has_move_target = true
	move_target = pos


func set_attack_focus(target: CombatUnit) -> void:
	if not alive or target == null or not target.alive:
		return
	has_move_target = false
	attack_focus = target


func try_attack(targets: Array) -> CombatUnit:
	if not alive or attack_timer > 0.0:
		return null
	var target := _nearest_hostile(targets, attack_range)
	if target == null:
		return null
	return try_attack_unit(target)


func try_attack_unit(target: CombatUnit) -> CombatUnit:
	if not alive or attack_timer > 0.0 or target == null or not target.alive:
		return null
	if global_position.distance_to(target.global_position) > attack_range * 1.05:
		return null
	attack_timer = attack_cooldown
	anim_busy = 0.35
	var anim := sprite as AnimatedSprite2D
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("attack"):
		anim.play("attack")
	var dmg := attack_damage + (agility * 0.35 if unit_kind == Kind.HERO else 0.0)
	if status_power > 0.0:
		dmg *= 1.35
	if is_god:
		dmg *= 1.15
	target.apply_damage(dmg, self)
	return target


func apply_damage(amount: float, source: CombatUnit) -> void:
	if not alive:
		return
	var eff_armor := armor + (6.0 if status_armor_buff > 0.0 else 0.0)
	var mitigated := amount * (100.0 / (100.0 + eff_armor * 4.0))
	hp -= mitigated
	last_attacker = source
	damaged.emit(self, mitigated, source)
	if status_reflect > 0.0 and source and source.alive and source.unit_kind != Kind.CREEP:
		source.hp -= mitigated * 0.3
		if source.hp <= 0.0:
			source._die(self)
	_update_bars()
	stats_changed.emit(self)
	if hp <= 0.0:
		_die(source)


func heal(amount: float) -> void:
	if not alive:
		return
	hp = minf(max_hp, hp + amount)
	_update_bars()
	stats_changed.emit(self)


func _die(killer: CombatUnit) -> void:
	if not alive:
		return
	alive = false
	hp = 0.0
	move_dir = Vector2.ZERO
	velocity = Vector2.ZERO
	clear_orders()
	if unit_kind == Kind.HERO:
		respawn_timer = 7.0 + level * 0.4
	died.emit(self, killer)


func respawn() -> void:
	alive = true
	hp = max_hp
	mana = max_mana * 0.65
	global_position = home_position
	respawn_timer = 0.0
	duel_locked = false
	clear_orders()
	_update_bars()
	stats_changed.emit(self)


func add_xp(amount: float) -> void:
	if unit_kind != Kind.HERO or not alive:
		return
	xp += amount
	while xp >= xp_to_level and level < 40:
		xp -= xp_to_level
		level += 1
		xp_to_level = 85.0 + level * 40.0
		max_hp += 40.0 + strength * 0.8
		hp += 40.0 + strength * 0.8
		attack_damage += 3.5 + agility * 0.15
		max_mana += 10.0 + intelligence * 0.4
		mana += 10.0
		strength += 1.2
		agility += 1.2
		intelligence += 1.2
	_update_bars()
	stats_changed.emit(self)


func add_gold(amount: int) -> void:
	gold += amount
	stats_changed.emit(self)


func buy_item(item: Dictionary) -> bool:
	if not alive or item.is_empty():
		return false
	var cost: int = int(item["cost"])
	if gold < cost:
		return false
	if item.get("consumable", false):
		gold -= cost
		heal(float(item.get("heal", 0.0)))
		stats_changed.emit(self)
		return true
	if items.size() >= 6:
		return false
	gold -= cost
	items.append(item["id"])
	var stats: Dictionary = item.get("stats", {})
	if stats.has("max_hp"):
		max_hp += float(stats["max_hp"])
		hp += float(stats["max_hp"])
	if stats.has("max_mana"):
		max_mana += float(stats["max_mana"])
		mana += float(stats["max_mana"])
	if stats.has("armor"):
		armor += float(stats["armor"])
	if stats.has("move_speed"):
		move_speed += float(stats["move_speed"])
	if stats.has("attack_damage"):
		attack_damage += float(stats["attack_damage"])
	_update_bars()
	stats_changed.emit(self)
	return true


func ability_ready(slot: int) -> bool:
	if slot < 0 or slot >= ability_cds.size():
		return false
	if not alive or hero_def.is_empty():
		return false
	var abilities: Array = hero_def.get("abilities", [])
	if slot >= abilities.size():
		return false
	var info: Dictionary = _HeroDefs.ability_info(abilities[slot])
	var mana_cost := float(info["mana"]) * (0.85 if is_god else 1.0)
	return ability_cds[slot] <= 0.0 and mana >= mana_cost


func cast_ability(slot: int, units: Array) -> bool:
	if not ability_ready(slot):
		return false
	var abilities: Array = hero_def.get("abilities", [])
	var ability_id: String = abilities[slot]
	var info: Dictionary = _HeroDefs.ability_info(ability_id)
	var mana_cost := float(info["mana"]) * (0.85 if is_god else 1.0)
	mana -= mana_cost
	ability_cds[slot] = float(info["cooldown"]) * (0.9 if is_god else 1.0)
	anim_busy = 0.3
	var anim := sprite as AnimatedSprite2D
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("attack"):
		anim.play("attack")
	_resolve_ability(ability_id, units)
	stats_changed.emit(self)
	return true


func _resolve_ability(ability_id: String, units: Array) -> void:
	var scale := 1.25 if is_god else 1.0
	match ability_id:
		"smite":
			var t := _nearest_hostile(units, 320.0)
			if t:
				t.apply_damage((90.0 + level * 12.0 + intelligence * 1.5) * scale, self)
		"mending_light":
			heal((110.0 + level * 15.0 + intelligence * 2.0) * scale)
		"ascendant_burst":
			_damage_aoe(units, 150.0, (80.0 + level * 10.0 + intelligence) * scale)
		"cinder_dash":
			var dir := move_dir if move_dir.length() > 0.1 else Vector2(0, 1 if team == GameSession.TEAM_LIGHT else -1)
			if has_move_target:
				dir = (move_target - global_position).normalized()
			elif attack_focus and is_instance_valid(attack_focus):
				dir = (attack_focus.global_position - global_position).normalized()
			global_position += dir.normalized() * (140.0 if not duel_locked else 80.0)
		"scorch":
			var t2 := _nearest_hostile(units, 220.0)
			if t2:
				t2.apply_damage((70.0 + level * 10.0 + agility) * scale, self)
				t2.status_slow = 2.0
		"inferno_form":
			status_power = 6.0
		"rip_current":
			var t3 := _nearest_hostile(units, 300.0)
			if t3:
				t3.apply_damage((65.0 + level * 8.0 + intelligence) * scale, self)
				t3.status_slow = 2.5
		"undertow":
			for u in units:
				var other := u as CombatUnit
				if other and other.alive and _is_hostile(other) and global_position.distance_to(other.global_position) <= 180.0:
					other.global_position = other.global_position.move_toward(global_position, 70.0)
					other.apply_damage(40.0 * scale, self)
		"tidal_crash":
			_damage_aoe(units, 170.0, (100.0 + level * 12.0 + intelligence) * scale)
		"bramble_skin":
			status_reflect = 4.0
		"root_snare":
			var t4 := _nearest_hostile(units, 240.0)
			if t4:
				t4.status_root = 1.6
				t4.apply_damage((50.0 + strength) * scale, self)
		"overgrowth":
			status_armor_buff = 5.0
			_damage_aoe(units, 140.0, (85.0 + level * 10.0 + strength) * scale)


func _damage_aoe(units: Array, radius: float, amount: float) -> void:
	for u in units:
		var other := u as CombatUnit
		if other and other.alive and _is_hostile(other) and global_position.distance_to(other.global_position) <= radius:
			other.apply_damage(amount, self)


func _is_hostile(other: CombatUnit) -> bool:
	if other == self:
		return false
	## Neutrals hostile to heroes; heroes hostile to other team + neutrals
	if unit_kind == Kind.HERO:
		if other.unit_kind == Kind.HERO:
			return other.team != team
		return true ## creeps/bosses
	## Creep/boss: hostile to heroes only
	return other.unit_kind == Kind.HERO


func _nearest_hostile(units: Array, range_limit: float) -> CombatUnit:
	var best: CombatUnit = null
	var best_d := range_limit
	for u in units:
		var other := u as CombatUnit
		if other == null or not other.alive or not _is_hostile(other):
			continue
		var d := global_position.distance_to(other.global_position)
		if d <= best_d:
			best_d = d
			best = other
	return best


func _nearest_enemy(units: Array, range_limit: float) -> CombatUnit:
	## Back-compat alias used by BotAI
	return _nearest_hostile(units, range_limit)


func _update_bars() -> void:
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = maxf(0.0, hp)
		hp_bar.visible = alive
		if unit_kind == Kind.HERO:
			hp_bar.modulate = Color(0.35, 0.8, 0.4) if team == GameSession.TEAM_LIGHT else Color(0.9, 0.35, 0.3)
		elif unit_kind == Kind.BOSS:
			hp_bar.modulate = Color(0.95, 0.75, 0.2)
		else:
			hp_bar.modulate = Color(0.75, 0.55, 0.85)
