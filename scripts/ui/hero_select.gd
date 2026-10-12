extends Control

## WC3 Angel Arena–style tavern stalls: tap a pedestal to pick, then Lock In.

const _HeroDefs = preload("res://scripts/data/hero_defs.gd")

@onready var stalls_row: HBoxContainer = $Safe/VBox/StallScroll/Stalls
@onready var name_label: Label = $Safe/VBox/Detail/Pad/Cols/TextCol/Name
@onready var role_label: Label = $Safe/VBox/Detail/Pad/Cols/TextCol/Role
@onready var blurb_label: Label = $Safe/VBox/Detail/Pad/Cols/TextCol/Blurb
@onready var portrait: TextureRect = $Safe/VBox/Detail/Pad/Cols/Portrait
@onready var lock_btn: Button = $Safe/VBox/LockBtn
@onready var back_btn: Button = $Safe/VBox/BackBtn
@onready var title: Label = $Safe/VBox/Title

var selected: String = "seraph"
var stall_buttons: Dictionary = {}


func _ready() -> void:
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	lock_btn.pressed.connect(_lock_in)
	title.text = "HERO TAVERN"
	_build_stalls()
	_select(GameSession.selected_hero_id)


func _build_stalls() -> void:
	for child in stalls_row.get_children():
		child.queue_free()
	stall_buttons.clear()
	for def in _HeroDefs.all():
		var stall := PanelContainer.new()
		stall.custom_minimum_size = Vector2(150, 260)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.1, 0.16, 0.95)
		style.border_color = Color(0.75, 0.6, 0.25, 0.85)
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		stall.add_theme_stylebox_override("panel", style)

		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		stall.add_child(col)

		var beam := ColorRect.new()
		beam.custom_minimum_size = Vector2(0, 8)
		beam.color = Color(0.55, 0.75, 1.0, 0.35)
		col.add_child(beam)

		var spr := TextureRect.new()
		spr.custom_minimum_size = Vector2(120, 120)
		spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		spr.texture = load(def["sprite"])
		col.add_child(spr)

		var nam := Label.new()
		nam.text = def["name"]
		nam.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nam.add_theme_font_size_override("font_size", 15)
		nam.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
		col.add_child(nam)

		var role := Label.new()
		role.text = def["role"]
		role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		role.add_theme_font_size_override("font_size", 11)
		role.add_theme_color_override("font_color", Color(0.7, 0.78, 0.88))
		col.add_child(role)

		var pick := Button.new()
		pick.text = "Select"
		pick.custom_minimum_size = Vector2(0, 40)
		var hid: String = def["id"]
		pick.pressed.connect(func(): _select(hid))
		## Whole stall also clickable
		stall.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed:
				_select(hid)
			elif ev is InputEventScreenTouch and ev.pressed:
				_select(hid)
		)
		col.add_child(pick)

		stalls_row.add_child(stall)
		stall_buttons[hid] = stall


func _select(hero_id: String) -> void:
	selected = hero_id
	GameSession.select_hero(hero_id)
	var def: Dictionary = _HeroDefs.by_id(hero_id)
	name_label.text = def["name"]
	role_label.text = def["role"]
	blurb_label.text = def["blurb"]
	portrait.texture = load(def["sprite"])
	lock_btn.text = "Lock In — %s" % def["name"]
	for hid in stall_buttons.keys():
		var panel: PanelContainer = stall_buttons[hid]
		var style := panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		if hid == hero_id:
			style.border_color = Color(1.0, 0.88, 0.35, 1)
			style.set_border_width_all(3)
			style.bg_color = Color(0.18, 0.15, 0.08, 0.98)
		else:
			style.border_color = Color(0.55, 0.45, 0.25, 0.7)
			style.set_border_width_all(2)
			style.bg_color = Color(0.12, 0.1, 0.16, 0.95)
		panel.add_theme_stylebox_override("panel", style)


func _lock_in() -> void:
	GameSession.select_hero(selected)
	GameSession.reset_result()
	get_tree().change_scene_to_file("res://scenes/match.tscn")
