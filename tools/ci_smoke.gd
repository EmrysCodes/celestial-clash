extends SceneTree
## CI smoke: load match, assert 4v4 lives/camps/boss, duel cycle, life drain.

var done := false

func _initialize() -> void:
	print("CI_SMOKE: start")
	var err := change_scene_to_file("res://scenes/match.tscn")
	if err != OK:
		printerr("CI_SMOKE: failed to load match scene: ", err)
		quit(1)


func _process(_dt: float) -> bool:
	if done:
		return true
	var t := Engine.get_process_frames()
	var m := get_root().get_node_or_null("Match")
	if t == 50:
		if m == null or not ("light_lives" in m):
			printerr("CI_SMOKE: Match script missing")
			done = true
			quit(1)
			return true
		print("CI_SMOKE: lives=", m.light_lives, "/", m.dark_lives)
		print("CI_SMOKE: units=", m.units.size(), " camps=", m.camp_states.size(), " bots=", m.bots.size())
		if m.light_lives != 20 or m.dark_lives != 20:
			printerr("CI_SMOKE: expected 20/20 lives")
			done = true
			quit(1)
			return true
		if m.camp_states.size() < 14:
			printerr("CI_SMOKE: expected >= 14 camps")
			done = true
			quit(1)
			return true
		if m.bots.size() < 7:
			printerr("CI_SMOKE: expected >= 7 bots for 4v4")
			done = true
			quit(1)
			return true
		if m.mid_boss == null:
			printerr("CI_SMOKE: mid boss missing")
			done = true
			quit(1)
			return true
		m.duel_timer = 0.05
	if t == 80 and m and m.duel_active:
		m.duel_time_left = 0.05
	if t == 120 and m:
		if m.duel_active:
			printerr("CI_SMOKE: duel did not end")
			done = true
			quit(1)
			return true
		print("CI_SMOKE: duel ended, next=", int(m.duel_timer))
		for u in m.units:
			if u.unit_kind == 0 and u.team == 1 and u.alive:
				u.apply_damage(99999.0, m.player_unit)
				break
	if t == 150 and m:
		print("CI_SMOKE: lives_after_kill=", m.light_lives, "/", m.dark_lives)
		if m.dark_lives != 19:
			printerr("CI_SMOKE: expected Ashen lives 19 after kill, got ", m.dark_lives)
			done = true
			quit(1)
			return true
		print("CI_SMOKE: pass")
		done = true
		quit(0)
		return true
	if t > 280:
		printerr("CI_SMOKE: timeout")
		done = true
		quit(1)
		return true
	return false
