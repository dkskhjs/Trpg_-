## 화면 캡처 확인용:
##   xvfb-run godot --path godot --script res://tests/screenshot.gd -- <출력 폴더>
extends SceneTree


func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
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
	main._open_sheet()
	await _frames(5)
	await _snap(out + "/g_sheet.png")
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
