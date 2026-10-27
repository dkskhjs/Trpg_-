## 명부를 실제 선택지로 따라가며 화면을 찍는다 (game_choose만 사용, go는 날짜 건너뛰기에만)
##   xvfb-run godot --path godot --rendering-driver opengl3 --script res://tests/ledger_play.gd -- <출력 폴더>
extends SceneTree
var main
var out := ""
var n := 0

func _pick(sub: String) -> bool:
	for st in main.game.visible_options():
		if sub in st.opt.t and not st.locked:
			main.game_choose(st)
			return true
	print("못 찾음: ", sub, " @", main.game.S.node, " ", main.game.visible_options().map(func(x): return x.opt.t))
	return false

func _shot(name: String) -> void:
	await create_timer(0.4).timeout
	if main.typing and main.typing.is_running(): main.typing.custom_step(999)
	await create_timer(0.3).timeout
	n += 1
	root.get_texture().get_image().save_png("%s/%02d_%s.png" % [out, n, name])

func _init() -> void:
	out = OS.get_cmdline_user_args()[0]
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.settings.lite = false
	main.settings.lite_auto_done = true
	await process_frame
	main._start_new(0)
	var g = main.game
	g.S.sp = 20
	for k in ["rhet", "hands", "empathy"]:
		g.S.bought[k] = 6
	# 1일째: 광장 → 박순녀 → 명단 요구(붉은 판정) → 품에 넣기
	_pick("눈을 뜬다")
	_pick("밖으로 나간다")
	_pick("인민반장에게")
	_pick("인민반 세대 명단")
	await _shot("d1_list")
	_pick("품에 넣는다")
	await _shot("d1_got_ledger")
	main._open_ledger("people")
	await _shot("d1_people")
	main._open_ledger("cheongsu")
	await _shot("d1_map")
	# 약도에서 하얀 집 누르기 → 볼펜 홈 읽기(손재주 붉은 판정)
	main._ledger_open_line(1)
	await _shot("d1_line")
	_pick("볼펜 홈")
	await _shot("d1_fix")
	_pick("명부를 다시 본다")
	_pick("빈 집 앞에")
	await _shot("d1_call")
	_pick("명부를 덮는다")
	main._open_ledger("cheongsu")
	await _shot("d1_map_after")
	main._close_modal()
	# 2일째: 박순녀 집에서 세 집 이름을 듣는다 (날짜 이동)
	g.S.day = 2
	g.go("square2")
	main._refresh()
	main._open_ledger("cheongsu")
	await _shot("d2_map_reach")
	main._close_modal()
	g.go("park_home2")
	_pick("지워진 세 세대")
	_pick("수첩에 적는다")
	main._open_ledger("people")
	await _shot("d2_people")
	main._close_modal()
	g.S.flags["th_signature"] = true
	main._ledger_open_line(2)
	_pick("덧붙인다")
	await _shot("d2_sorry")
	_pick("명부를 덮는다")
	# 5일째 삼지연: 약도에 문서고·암자, 흰 길
	g.S.day = 5
	for nid in ["d5_arrive", "d5_hub", "d5_archive", "d5_hub", "d5_temple", "d5_hub", "d5_caravan"]:
		g.go(nid)
	main._refresh()
	_pick("명부를 펼쳐 보인다")
	await _shot("d5_baek")
	_pick("돌려받는다")
	g.go("d5_hub")
	main._refresh()
	main._open_ledger("samjiyon")
	await _shot("d5_map")
	main._close_modal()
	main._open_sheet()
	await _shot("sheet")
	quit()
