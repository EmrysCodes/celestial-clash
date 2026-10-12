extends CanvasLayer

const _HeroDefs = preload("res://scripts/data/hero_defs.gd")
const _ItemDefs = preload("res://scripts/data/item_defs.gd")

@onready var score_label: Label = $TopChrome/Score
@onready var duel_label: Label = $TopChrome/Duel
@onready var objective_label: Label = $TopChrome/Objective
@onready var feed_label: Label = $TopChrome/Feed
@onready var gold_label: Label = $TopChrome/GoldChip/Gold
@onready var near_shop_label: Label = $TopChrome/NearShop
@onready var ascend_btn: Button = $TopChrome/AscendBtn

@onready var bottom: Control = $BottomBar
@onready var portrait: TextureRect = $BottomBar/PortraitFrame/Portrait
@onready var hero_name_label: Label = $BottomBar/Info/HeroName
@onready var level_label: Label = $BottomBar/Info/Level
@onready var hp_bar: TextureProgressBar = $BottomBar/Info/HpBar
@onready var mp_bar: TextureProgressBar = $BottomBar/Info/MpBar
@onready var hp_text: Label = $BottomBar/Info/HpBar/Text
@onready var mp_text: Label = $BottomBar/Info/MpBar/Text
@onready var inv_grid: GridContainer = $BottomBar/Inventory

@onready var touch: Control = $TouchControls
@onready var shop_panel: PanelContainer = $ShopPanel
@onready var shop_title: Label = $ShopPanel/Margin/VBox/Title
@onready var shop_list: VBoxContainer = $ShopPanel/Margin/VBox/List
@onready var result_panel: PanelContainer = $ResultPanel
@onready var result_label: Label = $ResultPanel/Margin/VBox/Result
@onready var menu_btn: Button = $ResultPanel/Margin/VBox/MenuBtn
@onready var boss_bar: ProgressBar = $BossBar
@onready var boss_label: Label = $BossBar/BossLabel
@onready var duel_banner: ColorRect = $DuelBanner
@onready var duel_banner_label: Label = $DuelBanner/Label
@onready var minimap: Control = $MinimapFrame/Minimap
@onready var hint_label: Label = $Hint

var match_ref: Node2D = null
var duel_flash_time: float = 0.0
var inv_slots: Array[TextureRect] = []


func setup(match_controller: Node2D) -> void:
	match_ref = match_controller
	match_ref.lives_changed.connect(_on_lives)
	match_ref.match_over.connect(_on_match_over)
	match_ref.unit_feed.connect(_on_feed)
	match_ref.duel_state_changed.connect(_on_duel)
	match_ref.shop_unlocks_changed.connect(_on_shop_unlock)
	match_ref.boss_hp_changed.connect(_on_boss_hp)
	touch.move_vector.connect(_on_move)
	touch.attack_pressed.connect(_on_attack)
	touch.ability_pressed.connect(_on_ability)
	touch.shop_pressed.connect(_on_shop)
	menu_btn.pressed.connect(_back_to_menu)
	ascend_btn.pressed.connect(_on_ascend)
	shop_panel.visible = false
	result_panel.visible = false
	ascend_btn.visible = false
	duel_banner.visible = false
	boss_bar.visible = false
	_build_inventory_slots()
	if minimap.has_method("setup"):
		minimap.setup(match_ref)
	_label_abilities()
	_on_lives(GameSession.LIVES_PER_TEAM, GameSession.LIVES_PER_TEAM)
	_refresh_objective()
	_refresh_portrait()
	refresh_shop()
	hint_label.text = "Joystick or tap ground to move · tap enemy to attack · skills on buttons"


func _build_inventory_slots() -> void:
	inv_slots.clear()
	for child in inv_grid.get_children():
		child.queue_free()
	for i in 6:
		var slot := TextureRect.new()
		slot.custom_minimum_size = Vector2(40, 40)
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.texture = load("res://assets/ui/hud/inv_slot.png")
		inv_grid.add_child(slot)
		inv_slots.append(slot)


func _process(delta: float) -> void:
	if match_ref == null:
		return
	var p: CombatUnit = match_ref.get_player()
	if p == null:
		return
	var shop_id: String = match_ref.nearest_shop_for(p)
	near_shop_label.visible = shop_id != "" and p.alive and not match_ref.duel_active
	if near_shop_label.visible:
		var lock := " (LOCKED)" if shop_id == "secret" and not match_ref.secret_unlocked else ""
		near_shop_label.text = "%s shop — tap Shop or the stall%s" % [shop_id.capitalize(), lock]

	hero_name_label.text = p.display_name
	level_label.text = "Lv %d%s" % [p.level, " · GOD" if p.is_god else ""]
	hp_bar.max_value = p.max_hp
	hp_bar.value = p.hp
	mp_bar.max_value = maxf(1.0, p.max_mana)
	mp_bar.value = p.mana
	hp_text.text = "%d / %d" % [int(p.hp), int(p.max_hp)]
	mp_text.text = "%d / %d" % [int(p.mana), int(p.max_mana)]
	gold_label.text = str(p.gold)

	_refresh_inventory(p)
	_refresh_cooldowns(p)

	ascend_btn.visible = match_ref.secret_unlocked and not p.is_god and p.level >= 8 and p.alive and not match_ref.duel_active
	if duel_flash_time > 0.0:
		duel_flash_time -= delta
		duel_banner.visible = true
		if duel_flash_time <= 0.0 and not match_ref.duel_active:
			duel_banner.visible = false


func _refresh_portrait() -> void:
	var p: CombatUnit = match_ref.get_player() if match_ref else null
	if p == null:
		return
	var path: String = String(p.hero_def.get("sprite", "res://assets/sprites/hero_seraph.png"))
	if ResourceLoader.exists(path):
		portrait.texture = load(path)


func _refresh_inventory(p: CombatUnit) -> void:
	for i in inv_slots.size():
		var slot := inv_slots[i]
		if i < p.items.size():
			var icon := _item_icon_path(p.items[i])
			if ResourceLoader.exists(icon):
				slot.texture = load(icon)
			else:
				slot.texture = load("res://assets/ui/hud/inv_slot.png")
			slot.modulate = Color(1, 1, 1, 1)
		else:
			slot.texture = load("res://assets/ui/hud/inv_slot.png")
			slot.modulate = Color(1, 1, 1, 0.85)


func _item_icon_path(item_id: String) -> String:
	if "boots" in item_id:
		return "res://assets/ui/icons/item_boots.png"
	if "blade" in item_id or "strike" in item_id or "sword" in item_id:
		return "res://assets/ui/icons/item_blade.png"
	if "buckler" in item_id or "shield" in item_id:
		return "res://assets/ui/icons/item_shield.png"
	if "mana" in item_id or "crystal" in item_id or "tome" in item_id:
		return "res://assets/ui/icons/item_tome.png"
	if "salve" in item_id or "potion" in item_id or "heal" in item_id:
		return "res://assets/ui/icons/item_potion.png"
	if "cloak" in item_id or "veil" in item_id:
		return "res://assets/ui/icons/item_cloak.png"
	if "ring" in item_id:
		return "res://assets/ui/icons/item_ring.png"
	if "amulet" in item_id or "crown" in item_id or "god" in item_id:
		return "res://assets/ui/icons/item_amulet.png"
	return "res://assets/ui/icons/item_ring.png"


func _refresh_cooldowns(p: CombatUnit) -> void:
	var abilities: Array = p.hero_def.get("abilities", [])
	var max_cds: Array = []
	for aid in abilities:
		max_cds.append(float(_HeroDefs.ability_info(aid).get("cooldown", 6.0)))
	if touch.has_method("set_cooldown_overlays"):
		touch.set_cooldown_overlays(p.ability_cds, max_cds)


func _label_abilities() -> void:
	var p: CombatUnit = match_ref.get_player()
	if p == null:
		return
	var names: Array = []
	var ids: Array = []
	for ability_id in p.hero_def.get("abilities", []):
		names.append(_HeroDefs.ability_info(ability_id)["name"])
		ids.append(ability_id)
	touch.set_ability_labels(names)
	if touch.has_method("set_ability_icons"):
		touch.set_ability_icons(ids)


func refresh_shop() -> void:
	for child in shop_list.get_children():
		child.queue_free()
	if match_ref == null:
		return
	var shop_id: String = match_ref.get_active_shop()
	var tier_blurb := {
		"base": "Starter gear — buy near your fountain",
		"mid": "Mid-game power — Burn Shield, Rapid Strike…",
		"secret": "Late godlike gear — unlocked after Mid Boss",
	}
	shop_title.text = "%s Shop" % shop_id.capitalize()
	var hint := Label.new()
	hint.text = String(tier_blurb.get(shop_id, ""))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shop_list.add_child(hint)
	if shop_id == "secret" and not match_ref.secret_unlocked:
		var locked := Label.new()
		locked.text = "Slay the Mid Boss to unseal this shop."
		locked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		shop_list.add_child(locked)
		return
	for item in _ItemDefs.for_shop(shop_id):
		var row := HBoxContainer.new()
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(36, 36)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var ipath := _item_icon_path(String(item["id"]))
		if ResourceLoader.exists(ipath):
			icon.texture = load(ipath)
		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.text = "%s — %s (%d g)" % [item["name"], item["blurb"], item["cost"]]
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var buy := Button.new()
		buy.text = "Buy"
		var item_id: String = item["id"]
		buy.pressed.connect(func(): _buy(item_id))
		row.add_child(icon)
		row.add_child(info)
		row.add_child(buy)
		shop_list.add_child(row)


func set_shop_open(open: bool) -> void:
	shop_panel.visible = open
	if open:
		refresh_shop()


func _buy(item_id: String) -> void:
	var p: CombatUnit = match_ref.get_player()
	if p == null:
		return
	match_ref.player_submit(InputCommand.buy(p.unit_id, item_id))


func _on_move(dir: Vector2) -> void:
	var p: CombatUnit = match_ref.get_player()
	if p:
		match_ref.player_submit(InputCommand.move(p.unit_id, dir))


func _on_attack() -> void:
	var p: CombatUnit = match_ref.get_player()
	if p:
		match_ref.player_submit(InputCommand.attack(p.unit_id))


func _on_ability(slot: int) -> void:
	var p: CombatUnit = match_ref.get_player()
	if p:
		match_ref.player_submit(InputCommand.ability(p.unit_id, slot))


func _on_shop() -> void:
	var p: CombatUnit = match_ref.get_player()
	if p:
		match_ref.player_submit(InputCommand.shop_toggle(p.unit_id))


func _on_ascend() -> void:
	var p: CombatUnit = match_ref.get_player()
	if p:
		match_ref.player_submit({"type": "ascend", "unit_id": p.unit_id})


func _on_lives(light_lives: int, dark_lives: int) -> void:
	score_label.text = "Seraphim %d   —   Ashen %d" % [light_lives, dark_lives]


func _on_duel(state: String, seconds: float) -> void:
	if state == "active":
		duel_label.text = "DUEL LIVE — %.0fs" % seconds
		duel_label.modulate = Color(1.0, 0.85, 0.3)
		duel_banner.visible = true
		duel_banner_label.text = "DUEL — FIGHT!"
		duel_flash_time = 2.2
	else:
		duel_label.text = "Next duel in %.0fs" % maxf(0.0, seconds)
		duel_label.modulate = Color(0.8, 0.85, 0.9)
		if seconds <= 8.0 and seconds > 7.5:
			duel_banner.visible = true
			duel_banner_label.text = "DUEL INCOMING"
			duel_flash_time = 1.5


func _on_boss_hp(current: float, maximum: float, alive: bool) -> void:
	boss_bar.visible = alive
	if alive:
		boss_bar.max_value = maximum
		boss_bar.value = current
		boss_label.text = "MID BOSS  %d / %d" % [int(current), int(maximum)]


func _on_shop_unlock(_open: bool) -> void:
	refresh_shop()
	_refresh_objective()


func _refresh_objective() -> void:
	if match_ref == null:
		return
	if not match_ref.secret_unlocked:
		objective_label.text = "Farm → gear → Mid Boss"
	else:
		objective_label.text = "Secret Shop open — Ascend & drain lives"


func _on_feed(message: String) -> void:
	feed_label.text = message


func _on_match_over(winning_team: int) -> void:
	result_panel.visible = true
	var won := winning_team == GameSession.player_team
	result_label.text = ("Victory!" if won else "Defeat.") + "\n%s win with %d–%d lives left" % [
		GameSession.team_name(winning_team),
		GameSession.last_result.get("light_lives", 0),
		GameSession.last_result.get("dark_lives", 0),
	]


func _back_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
