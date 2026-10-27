## 보관 칸 시험: 자동 보관, 칸별 보관·불러오기, 예전 save.json 옮기기, 이어하기가 최근 칸을 고르는지
##   godot --headless --path godot --script res://tests/save_slots.gd
extends SceneTree

func _fail(msg: String) -> void:
	print("실패: ", msg)
	quit(1)

func _init() -> void:
	_run()


func _run() -> void:
	for slot in Game.SLOTS:
		DirAccess.remove_absolute(Game.slot_path(slot))
	# 예전 한 칸짜리 파일이 1번 칸으로 옮겨지는지
	var old := Game.new()
	old.new_game(0)
	var f := FileAccess.open(Game.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(old.S))
	f.close()
	Game.migrate_old_save()
	if not FileAccess.file_exists(Game.slot_path("1")) or FileAccess.file_exists(Game.SAVE_PATH):
		return _fail("예전 보관 파일 옮기기")
	var g := Game.new()
	g.new_game(1)
	for i in 6:
		g.choose(g.visible_options().filter(func(x): return not x.locked)[0])
	if not g.save_game("2"):
		return _fail("2번 칸 보관")
	var node2: String = g.S.node
	await create_timer(1.1).timeout   # 보관 시각이 초 단위라 1초 띄운다
	g.choose(g.visible_options().filter(func(x): return not x.locked)[0])
	g.save_game("auto")
	var h := Game.new()
	if not h.load_game("2") or h.S.node != node2:
		return _fail("2번 칸 불러오기")
	if Game.latest_slot() != "auto":
		return _fail("가장 최근 칸은 auto여야 함: " + Game.latest_slot())
	var info := Game.slot_info("2")
	if info.is_empty() or info.scene == "":
		return _fail("칸 요약")
	# 파일 올리기: 엉뚱한 파일은 거절하고, 내려받은 파일은 받아들인다
	if h.import_text("{}", "3") == "" or h.import_text("아무 글", "3") == "":
		return _fail("잘못된 파일을 받아들임")
	if h.import_text(Game.slot_text("2"), "3") != "" or Game.read_slot("3").node != node2:
		return _fail("내려받은 파일 올리기")
	print("보관 칸 시험 통과: ", info)
	quit(0)
