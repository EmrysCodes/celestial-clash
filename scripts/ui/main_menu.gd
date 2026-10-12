extends Control

@onready var play_btn: Button = $Safe/VBox/PlayBtn
@onready var how_btn: Button = $Safe/VBox/HowBtn
@onready var how_panel: PanelContainer = $HowPanel
@onready var close_how: Button = $HowPanel/Margin/VBox/CloseBtn
@onready var subtitle: Label = $Safe/VBox/Subtitle
@onready var net_label: Label = $Safe/VBox/NetLabel


func _ready() -> void:
	play_btn.pressed.connect(_on_play)
	how_btn.pressed.connect(func(): how_panel.visible = true)
	close_how.pressed.connect(func(): how_panel.visible = false)
	how_panel.visible = false
	net_label.text = NetBridge.describe()
	subtitle.text = "Lives. Camps. Duels. Gods.\nAngel Arena soul — rebuilt for touch."


func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/hero_select.tscn")
