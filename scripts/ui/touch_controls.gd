extends Control

## Left joystick + WC3-style command card (skills stay on buttons).

signal move_vector(dir: Vector2)
signal attack_pressed
signal ability_pressed(slot: int)
signal shop_pressed

@onready var stick_base: TextureRect = $Joystick/Base
@onready var stick_knob: TextureRect = $Joystick/Knob
@onready var attack_btn: TextureButton = $CommandCard/Attack
@onready var shop_btn: TextureButton = $CommandCard/Shop
@onready var ability_buttons: Array[TextureButton] = [
	$CommandCard/A1, $CommandCard/A2, $CommandCard/A3
]

var dragging := false
var touch_index := -1
var max_radius := 56.0
var current_dir := Vector2.ZERO


func _ready() -> void:
	attack_btn.pressed.connect(func(): attack_pressed.emit())
	shop_btn.pressed.connect(func(): shop_pressed.emit())
	for i in ability_buttons.size():
		var idx := i
		ability_buttons[i].pressed.connect(func(): ability_pressed.emit(idx))
	stick_knob.position = stick_base.position + stick_base.size * 0.5 - stick_knob.size * 0.5


func _process(_delta: float) -> void:
	var k := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if k.length() > 0.1 and not dragging:
		current_dir = k
		move_vector.emit(current_dir)
		_set_knob(current_dir * max_radius)
	elif not dragging and k.length() <= 0.1 and current_dir.length() > 0.0 and not (
		Input.is_action_pressed("move_left")
		or Input.is_action_pressed("move_right")
		or Input.is_action_pressed("move_up")
		or Input.is_action_pressed("move_down")
	):
		current_dir = Vector2.ZERO
		move_vector.emit(current_dir)
		_set_knob(Vector2.ZERO)

	if Input.is_action_just_pressed("attack"):
		attack_pressed.emit()
	if Input.is_action_just_pressed("ability_1"):
		ability_pressed.emit(0)
	if Input.is_action_just_pressed("ability_2"):
		ability_pressed.emit(1)
	if Input.is_action_just_pressed("ability_3"):
		ability_pressed.emit(2)
	if Input.is_action_just_pressed("shop"):
		shop_pressed.emit()


func _on_joystick_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed and not dragging:
			dragging = true
			touch_index = st.index
			_update_stick(st.position)
		elif not st.pressed and st.index == touch_index:
			dragging = false
			touch_index = -1
			current_dir = Vector2.ZERO
			move_vector.emit(current_dir)
			_set_knob(Vector2.ZERO)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if dragging and sd.index == touch_index:
			_update_stick(sd.position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				dragging = true
				touch_index = 0
				_update_stick(mb.position)
			else:
				dragging = false
				touch_index = -1
				current_dir = Vector2.ZERO
				move_vector.emit(current_dir)
				_set_knob(Vector2.ZERO)
	elif event is InputEventMouseMotion and dragging:
		_update_stick((event as InputEventMouseMotion).position)


func _update_stick(local_pos: Vector2) -> void:
	var center := stick_base.position + stick_base.size * 0.5
	var offset := local_pos - center
	if offset.length() > max_radius:
		offset = offset.normalized() * max_radius
	current_dir = offset / max_radius
	move_vector.emit(current_dir)
	_set_knob(offset)


func _set_knob(offset: Vector2) -> void:
	var center := stick_base.position + stick_base.size * 0.5
	stick_knob.position = center + offset - stick_knob.size * 0.5


func set_ability_labels(names: Array) -> void:
	for i in ability_buttons.size():
		var label := ability_buttons[i].get_node_or_null("Label") as Label
		if label and i < names.size():
			label.text = str(names[i])


func set_ability_icons(ability_ids: Array) -> void:
	for i in ability_buttons.size():
		if i >= ability_ids.size():
			continue
		var path := "res://assets/ui/icons/ability_%s.png" % String(ability_ids[i])
		if ResourceLoader.exists(path):
			ability_buttons[i].texture_normal = load(path)


func set_cooldown_overlays(cds: Array, max_cds: Array) -> void:
	for i in ability_buttons.size():
		var overlay := ability_buttons[i].get_node_or_null("CD") as ColorRect
		if overlay == null:
			continue
		var cd := float(cds[i]) if i < cds.size() else 0.0
		var mx := float(max_cds[i]) if i < max_cds.size() else 1.0
		if cd <= 0.0 or mx <= 0.0:
			overlay.visible = false
		else:
			overlay.visible = true
			overlay.anchor_top = 1.0 - clampf(cd / mx, 0.0, 1.0)
