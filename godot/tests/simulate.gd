## 헤드리스 무작위 플레이 테스트:
##   godot --headless --path godot --script res://tests/simulate.gd
extends SceneTree

const RUNS := 1500


func _init() -> void:
	var ends := {}
	var seen := {}
	var stuck := []
	for r in RUNS:
		var g := Game.new() if r == 0 else _shared
		if r == 0:
			_shared = g
		g.new_game(r % 4)
		var god := r % 3 != 0
		for step in 600:
			seen[g.S.node] = true
			if g.node().get("ending", false):
				break
			if god:
				g.S.hp = 999
				g.S.morale = 999
			if r % 2 == 1 and g.S.thoughts.active == "" and g.S.thoughts.known.size() > 0:
				g.internalize(g.S.thoughts.known[0])
			var opts := g.visible_options().filter(func(s): return not s.locked)
			if opts.is_empty():
				stuck.append(g.S.node)
				break
			g.choose(opts[randi() % opts.size()])
		ends[g.S.node] = ends.get(g.S.node, 0) + 1
	var unseen := g_unseen(seen)
	print("결말 분포: ", ends)
	print("방문하지 못한 노드: ", unseen)
	print("막힌 노드: ", stuck)
	# 명부 장면: 펼쳐서 무엇을 고르든 결국 덮고 원래 장면으로 돌아오는지
	var ledger_stuck := []
	for r in 300:
		var lg := Game.new()
		lg.errors = _shared.errors
		lg.new_game(r % 4)
		lg.go("square2")
		if r % 2 == 0:
			lg.S.flags["park_named"] = true
		if r % 5 == 0:
			lg.S.flags["th_signature"] = true
		for hid in ["yong", "bok", "tae"]:
			lg.open_ledger("lg_" + hid, r % 3 != 0)
			for step in 20:
				if not str(lg.S.node).begins_with("lg_"):
					break
				var lopts := lg.visible_options().filter(func(x): return not x.locked)
				lg.choose(lopts[randi() % lopts.size()])
			if lg.S.node != "square2":
				ledger_stuck.append("lg_%s → %s" % [hid, lg.S.node])
	print("명부 장면에서 못 돌아옴: ", ledger_stuck)
	# 명부 자료: 적힌 노드가 실제로 있는지, 조건식이 해석되는지
	var ledger: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ledger.json"))
	var bad_nodes := []
	var conds := []
	for hh in ledger.households:
		for key in ["known_if", "name_if", "called_if", "smudged_if"]:
			if hh.has(key):
				conds.append(hh[key])
		for person in hh.people:
			if person.has("white_if"):
				conds.append(person.white_if)
	for m in ledger.maps:
		if m.has("show_if"):
			conds.append(m.show_if)
		for pl in m.places:
			if pl.has("known_if"):
				conds.append(pl.known_if)
			for n in pl.nodes:
				if not _shared.story.has(n):
					bad_nodes.append(n)
	var dossier: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dossier.json"))
	for row in dossier.rows:
		for st in row.get("steps", []) + row.get("items", []):
			conds.append(st["if"])
	for c in conds:
		_shared.eval_cond(c)
	print("명부에 적힌 없는 노드: ", bad_nodes)
	print("조건식 오류: ", _shared.errors)
	quit(1 if stuck.size() > 0 or _shared.errors.size() > 0 or bad_nodes.size() > 0 or ledger_stuck.size() > 0 else 0)


var _shared: Game


func g_unseen(seen: Dictionary) -> Array:
	return _shared.story.keys().filter(func(k): return not seen.has(k))
