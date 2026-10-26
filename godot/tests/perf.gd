## 장면별 평균 프레임 시간 측정 (소프트웨어 렌더링이라 절대값보다 상대 비교용)
##   xvfb-run godot --path godot --rendering-driver opengl3 --script res://tests/perf.gd
extends SceneTree

func _measure(label: String, secs: float) -> void:
	var t0 := Time.get_ticks_usec()
	var frames := 0
	while Time.get_ticks_usec() - t0 < secs * 1000000.0:
		await process_frame
		frames += 1
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / frames
	print("%-28s %6.1f ms/frame  (%d frames)" % [label, ms, frames])

func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.settings.lite = false   # 테스트 기기가 느려 자동으로 켜졌을 수 있다
	main.settings.lite_auto_done = true
	for i in 10:
		await process_frame
	await _measure("첫화면", 2.0)
	main._start_new(1)
	main._finish_typing()
	await _measure("초대소 (창백 0)", 2.0)
	# 로그를 길게 쌓은 뒤 타자기 효과
	for i in 120:
		main.game.push("narr", "가나다라마바사아자차카타파하 " .repeat(6))
	main.rendered_serial = 0
	main._render_log()
	main._finish_typing()
	main.game.go("square")
	main._refresh()
	await _measure("긴 로그 + 타자기 진행 중", 2.0)
	main._finish_typing()
	main.game.S.pale = 7
	main.game.go("river")
	main._refresh()
	main._finish_typing()
	await create_timer(3.0).timeout
	await _measure("강가 풍경 + 창백 7", 2.0)
	main.settings.lite = true
	main._update_overlay_visibility()
	main.backgrounds[main.bg_active].material = null
	await _measure("같은 장면, 가벼운 화면", 2.0)
	main.settings.lite = false
	quit()
