## 화면 캡처 확인용:
##   xvfb-run godot --path godot --script res://tests/screenshot.gd -- <출력 폴더>
extends SceneTree


func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	await _snap(out + "/g_title.png")
	main._open_start()
	await _frames(5)
	await _snap(out + "/g_start.png")
	main._start_new(1)
	for i in 3:
		main.game_choose(main.game.visible_options()[0])
	await _frames(5)
	await _snap(out + "/g_play.png")
	main.game_choose(main.game.visible_options()[0])
	await create_timer(0.6).timeout
	await _snap(out + "/g_typing.png", false)
	main.game.apply({"item": ["potato", "claw", "radio"], "rep": {"bear": 2, "pioneers": 1}, "thought": "reaction"})
	main._open_sheet()
	await _frames(5)
	await _snap(out + "/g_sheet.png")
	main._open_thoughts()
	await _frames(5)
	await _snap(out + "/g_thoughts.png")
	main._open_settings()
	await _frames(5)
	await _snap(out + "/g_settings.png")
	main._close_modal()
	# 창백 노출이 높을 때 강가 화면
	main.game.go("station")
	main.game.go("oh_lastnight")
	main._refresh()
	await create_timer(1.0).timeout
	await _snap(out + "/g_npc.png")
	main.game.S.pale = 3
	main.game.go("square")
	main._refresh()
	await create_timer(2.5).timeout
	await _snap(out + "/g_pale_mid.png")
	main.game.S.pale = 7
	main.game.go("river")
	main._refresh()
	await create_timer(2.5).timeout
	await _snap(out + "/g_pale.png")
	# 명부: 1일째 박순녀에게서 받은 직후(세 집이 하얗다) → 이름을 되찾은 뒤 · 확장 분기 약도 · 삼지연 약도
	main.game.new_game(0)
	for n in ["room", "square", "park", "park_list"]:
		main.game.go(n)
	main.game.apply({"item": "ledger"})
	main._refresh()
	await create_timer(0.5).timeout
	await _snap(out + "/g_ledger_side.png")
	main._open_ledger("people")
	await _frames(5)
	await _snap(out + "/g_ledger_people.png")
	main._open_ledger("cheongsu")
	await _frames(5)
	await _snap(out + "/g_ledger_map1.png")
	for n in ["station", "market", "graves", "night1", "park_home2", "park_names", "square2"]:
		main.game.go(n)
	main._open_ledger("people")
	await _frames(5)
	await _snap(out + "/g_ledger_people2.png")
	main._open_ledger("cheongsu")
	await _frames(5)
	await _snap(out + "/g_ledger_map2.png")
	# 하얘진 집 줄을 열어 그 집 앞에서 이름을 부른다
	main._ledger_open_line(1)
	await create_timer(0.3).timeout
	await _snap(out + "/g_ledger_line.png")
	main.game_choose(main.game.visible_options()[0])
	await create_timer(0.3).timeout
	await _snap(out + "/g_ledger_call.png")
	main.game_choose(main.game.visible_options()[0])
	main.game.S.flags["pale_expanded"] = true
	main._open_ledger("cheongsu")
	await _frames(5)
	await _snap(out + "/g_ledger_map2b.png")
	for n in ["d5_arrive", "d5_hub", "d5_plaza", "d5_bear", "d5_lab", "d5_caravan", "d5_baek_ledger", "d5_hub"]:
		main.game.go(n)
	main._open_ledger("samjiyon")
	await _frames(5)
	await _snap(out + "/g_ledger_map3.png")
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## finish=false면 타자기 효과가 진행 중인 화면을 그대로 찍는다.
func _snap(path: String, finish := true) -> void:
	if finish:
		root.get_node("Main")._finish_typing()
	await process_frame
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
