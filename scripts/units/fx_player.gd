class_name FxPlayer
extends Node2D

## Spritesheet bursts + CPUParticles2D skill FX.


static func play(parent: Node, sheet_path: String, pos: Vector2, frame_size: int = 64, fps: float = 14.0, scale_mul: float = 1.0) -> void:
	if parent == null:
		return
	var tex: Texture2D = load(sheet_path) as Texture2D
	if tex == null:
		return
	var node := AnimatedSprite2D.new()
	node.z_index = 20
	node.global_position = pos
	node.scale = Vector2(scale_mul, scale_mul)
	var frames := SpriteFrames.new()
	frames.add_animation("fx")
	frames.set_animation_loop("fx", false)
	frames.set_animation_speed("fx", fps)
	var cols: int = maxi(1, int(tex.get_width() / float(frame_size)))
	for i in cols:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * frame_size, 0, frame_size, frame_size)
		frames.add_frame("fx", at)
	node.sprite_frames = frames
	parent.add_child(node)
	node.play("fx")
	node.animation_finished.connect(node.queue_free)


static func gold_popup(parent: Node, pos: Vector2, amount: int) -> void:
	if parent == null:
		return
	var lbl := Label.new()
	lbl.text = "+%d" % amount
	lbl.z_index = 25
	lbl.global_position = pos + Vector2(-12, -30)
	lbl.modulate = Color(1.0, 0.85, 0.3, 1)
	lbl.add_theme_font_size_override("font_size", 14)
	parent.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "global_position", lbl.global_position + Vector2(0, -36), 0.7)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.7)
	tw.tween_callback(lbl.queue_free)


static func particles(parent: Node, pos: Vector2, kind: String, lifetime: float = 0.55) -> void:
	if parent == null:
		return
	var p := CPUParticles2D.new()
	p.z_index = 22
	p.global_position = pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.85
	p.lifetime = lifetime
	p.amount = 28
	p.spread = 180.0
	p.direction = Vector2(0, -1)
	p.gravity = Vector2(0, 40)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 140.0
	p.scale_amount_min = 0.35
	p.scale_amount_max = 1.1
	p.damping_min = 2.0
	p.damping_max = 6.0
	var tex_path := "res://assets/sprites/fx/particle_soft.png"
	var color := Color(1, 1, 1, 1)
	match kind:
		"holy", "smite", "ascendant_burst", "mending_light":
			tex_path = "res://assets/sprites/fx/particle_holy.png"
			color = Color(1.0, 0.95, 0.7, 1)
			p.amount = 36
		"fire", "cinder_dash", "scorch", "inferno_form":
			tex_path = "res://assets/sprites/fx/particle_fire.png"
			color = Color(1.0, 0.45, 0.15, 1)
			p.gravity = Vector2(0, -20)
		"water", "rip_current", "undertow", "tidal_crash":
			tex_path = "res://assets/sprites/fx/particle_water.png"
			color = Color(0.4, 0.7, 1.0, 1)
		"nature", "bramble_skin", "root_snare", "overgrowth":
			tex_path = "res://assets/sprites/fx/particle_nature.png"
			color = Color(0.45, 0.9, 0.35, 1)
		"hit":
			tex_path = "res://assets/sprites/fx/particle_spark.png"
			color = Color(1.0, 0.85, 0.4, 1)
			p.amount = 16
			p.lifetime = 0.35
		"ascend":
			tex_path = "res://assets/sprites/fx/particle_holy.png"
			color = Color(1.0, 0.9, 0.45, 1)
			p.amount = 48
			p.lifetime = 0.9
			p.initial_velocity_max = 200.0
	if ResourceLoader.exists(tex_path):
		p.texture = load(tex_path)
	p.color = color
	parent.add_child(p)
	# Auto-free after burst
	var timer := Timer.new()
	timer.wait_time = lifetime + 0.35
	timer.one_shot = true
	p.add_child(timer)
	timer.timeout.connect(p.queue_free)
	timer.start()


static func ability(parent: Node, pos: Vector2, ability_id: String) -> void:
	var burst := "res://assets/sprites/fx/hit_burst.png"
	var kind := "hit"
	match ability_id:
		"smite", "ascendant_burst", "mending_light":
			burst = "res://assets/sprites/fx/holy_burst.png"
			kind = "holy"
		"cinder_dash", "scorch", "inferno_form":
			burst = "res://assets/sprites/fx/fire_burst.png"
			kind = "fire"
		"rip_current", "undertow", "tidal_crash":
			burst = "res://assets/sprites/fx/water_burst.png"
			kind = "water"
		"bramble_skin", "root_snare", "overgrowth":
			burst = "res://assets/sprites/fx/nature_burst.png"
			kind = "nature"
	if ability_id in ["ascendant_burst", "tidal_crash", "overgrowth", "inferno_form"]:
		play(parent, "res://assets/sprites/fx/nova_ring.png", pos, 80, 14.0, 1.2)
	play(parent, burst, pos, 64, 14.0, 1.05)
	particles(parent, pos, kind)
