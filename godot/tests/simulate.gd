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
	quit(1 if stuck.size() > 0 else 0)


var _shared: Game


func g_unseen(seen: Dictionary) -> Array:
	return _shared.story.keys().filter(func(k): return not seen.has(k))
