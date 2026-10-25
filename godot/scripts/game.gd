## 게임 상태와 규칙. UI와 분리되어 있어 헤드리스 테스트에서도 그대로 쓴다.
class_name Game
extends RefCounted

const SAVE_PATH := "user://save.json"
const LOG_LIMIT := 400
const ATTR_COLORS := {"int": "#5fb0d0", "psy": "#a68be0", "fys": "#d0625a", "mot": "#d8b54c"}
const PALE_STAGES := ["희미함", "번짐", "침식", "잠식", "백색"]

var world: Dictionary
var story: Dictionary
var S: Dictionary = {}          # 저장되는 상태 전체
var log_serial := 0             # 지금까지 추가된 로그 수 (UI 증분 렌더링용)
var events: Array[String] = []  # 이번 행동에서 일어난 일 (소리·화면 효과용). UI가 비운다.
var _expr_cache := {}


func _init() -> void:
	world = _load_json("res://data/world.json")
	story = _load_json("res://data/story.json")


func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	assert(f != null, "데이터 파일 없음: " + path)
	return JSON.parse_string(f.get_as_text())


# ---------- 상태 ----------
func new_game(arch_index: int) -> void:
	var arch: Dictionary = world.ARCHETYPES[arch_index]
	S = {
		"arch": arch.id, "attrs": arch.attrs.duplicate(), "bought": {}, "sp": 2,
		"hp": 0, "morale": 0, "node": "", "flags": {}, "visited": {}, "checks": {}, "used": {},
		"pale": 0, "ticks": 0, "day": 1, "day_tick": 0, "names": [],
		"thoughts": {"known": [], "active": "", "progress": 0, "done": []}, "log": [],
	}
	S.hp = max_hp()
	S.morale = max_morale()
	log_serial = 0
	sys("— %s —" % arch.name)
	go("start")


func has_game() -> bool:
	return not S.is_empty()


func max_hp() -> int:
	return int(S.attrs.fys) + 2


func max_morale() -> int:
	return int(S.attrs.psy) + 2


func thought_bonus(k: String) -> int:
	var b := 0
	for id in S.thoughts.done:
		b += int(world.THOUGHTS[id].bonus.get(k, 0))
	return b


func level(k: String) -> int:
	var attr: String = world.SKILLS[k].attr
	return maxi(0, int(S.attrs[attr]) + int(S.bought.get(k, 0)) + thought_bonus(k))


func skill_color(k: String) -> String:
	return ATTR_COLORS[world.SKILLS[k].attr]


func diff_name(dc) -> String:
	return world.DIFF[str(int(dc))]


static func chance(lvl: int, dc: int) -> int:
	var ok := 0
	for a in range(1, 7):
		for b in range(1, 7):
			if a == 6 and b == 6:
				ok += 1
			elif not (a == 1 and b == 1) and a + b + lvl >= dc:
				ok += 1
	return roundi(ok / 36.0 * 100.0)


## 0~1. 화면이 바래는 정도.
func pale_intensity() -> float:
	return clampf(float(S.pale) / 10.0, 0.0, 0.85)


func pale_stage() -> String:
	return PALE_STAGES[mini(4, int(S.pale) / 2)]


## 그날 자정부터 지난 분. 아침 06:40에 시작해 선택 하나에 10분씩 흐른다.
func minutes() -> int:
	return mini(23 * 60 + 50, 6 * 60 + 40 + (int(S.ticks) - int(S.day_tick)) * 10)


func clock_text() -> String:
	var m := minutes()
	return "%d일째 · %02d:%02d · 주체 ??년" % [int(S.day), m / 60, m % 60]


# ---------- 조건식 (Expression의 base_instance로 이 객체를 넘긴다) ----------
func flag(n: String) -> bool:
	return S.flags.get(n, false)


func visited(n: String) -> int:
	return int(S.visited.get(n, 0))


func names_count() -> int:
	return S.names.size()


func has_name(n: String) -> bool:
	return n in S.names


func eval_cond(src: String) -> bool:
	var e: Expression = _expr_cache.get(src)
	if e == null:
		e = Expression.new()
		var err := e.parse(src)
		assert(err == OK, "조건식 파싱 실패: %s (%s)" % [src, e.get_error_text()])
		_expr_cache[src] = e
	var r = e.execute([], self, true)
	assert(not e.has_execute_failed(), "조건식 실행 실패: " + src)
	return bool(r)


func resolve_line(entry) -> String:
	if entry is String:
		return _placeholders(entry)
	if entry is Dictionary:
		var branch = entry.get("then") if eval_cond(entry["if"]) else entry.get("else")
		return "" if branch == null else resolve_line(branch)
	return ""


func _placeholders(s: String) -> String:
	if not "{" in s:
		return s
	return s.replace("{names_dot}", ". ".join(S.names)).replace("{names_count}", str(S.names.size())).replace("{names}", ", ".join(S.names))


# ---------- 로그 ----------
static func esc(s: String) -> String:
	return s.replace("[", "[lb]")


func push(cls: String, bb: String) -> void:
	S.log.append([cls, bb])
	if S.log.size() > LOG_LIMIT:
		S.log.pop_front()
	log_serial += 1


func sys(t: String) -> void:
	push("sys", "[center][color=#dfe3e3]%s[/color][/center]" % esc(t))


func fx_note(t: String) -> void:
	push("fx", "[font_size=15][color=#8f877a]%s[/color][/font_size]" % esc(t))


func skill_tag(k: String) -> String:
	return "[color=%s][b]%s[/b][/color]" % [skill_color(k), esc(world.SKILLS[k].name)]


var _re_voice := RegEx.create_from_string("^@(\\w+):\\s*(.*)$")
var _re_npc := RegEx.create_from_string("^#([^:]+):\\s*(.*)$")

func add_line(raw: String) -> void:
	if raw.is_empty():
		return
	var m := _re_voice.search(raw)
	if m:
		push("voice", "%s — %s" % [skill_tag(m.get_string(1)), esc(m.get_string(2))])
		return
	m = _re_npc.search(raw)
	if m:
		push("npc", "[color=#e8c890][b]%s[/b][/color] — %s" % [esc(m.get_string(1)), esc(m.get_string(2))])
		return
	push("narr", esc(raw))


# ---------- 효과 ----------
func apply(fx) -> void:
	if fx == null:
		return
	if fx.has("if"):
		apply(fx.get("then") if eval_cond(fx["if"]) else fx.get("else"))
		return
	for k in _as_list(fx.get("flag")):
		S.flags[k] = true
	for k in _as_list(fx.get("unflag")):
		S.flags.erase(k)
	if fx.has("hp"):
		var v := int(fx.hp)
		S.hp = mini(max_hp(), int(S.hp) + v)
		fx_note("체력 %+d" % v)
	if fx.has("morale"):
		var v := int(fx.morale)
		S.morale = mini(max_morale(), int(S.morale) + v)
		fx_note("사기 %+d" % v)
	if fx.has("sp"):
		S.sp = int(S.sp) + int(fx.sp)
		fx_note("기술 점수 +%d" % int(fx.sp))
	if fx.has("pale"):
		S.pale = maxi(0, int(S.pale) + int(fx.pale))
		if int(fx.pale) < 0:
			fx_note("창백이 조금 물러난다.")
			events.append("pale_down")
		else:
			events.append("pale_up")
	for nm in _as_list(fx.get("name")):
		if not nm in S.names:
			S.names.append(nm)
			fx_note("이름을 기억했다: " + nm)
			events.append("name")
	if fx.has("day"):
		S.day = int(fx.day)
		S.day_tick = S.ticks
		S.flags["day%d" % int(fx.day)] = true
	var th = fx.get("thought")
	if th and not th in S.thoughts.known and not th in S.thoughts.done:
		S.thoughts.known.append(th)
		events.append("thought_new")
		fx_note("새 사상: 「%s」 — 사상함에서 내면화할 수 있다." % world.THOUGHTS[th].name)


func _as_list(v) -> Array:
	if v == null:
		return []
	return v if v is Array else [v]


func tick() -> void:
	S.ticks = int(S.ticks) + 1
	var t: Dictionary = S.thoughts
	if t.active == "":
		return
	t.progress = int(t.progress) + 1
	var th: Dictionary = world.THOUGHTS[t.active]
	if t.progress >= int(th.time):
		t.done.append(t.active)
		t.known.erase(t.active)
		S.flags[th.flag] = true
		events.append("thought_done")
		push("voice", "[color=#dfe3e3][b]사상 내면화 완료: 「%s」[/b][/color] — %s" % [esc(th.name), esc(th.a)])
		t.active = ""
		t.progress = 0


func internalize(id: String) -> void:
	S.thoughts.active = id
	S.thoughts.progress = 0
	fx_note("「%s」을(를) 품기 시작한다." % world.THOUGHTS[id].name)


func buy(k: String) -> bool:
	var attr: String = world.SKILLS[k].attr
	if int(S.sp) <= 0 or int(S.bought.get(k, 0)) >= int(S.attrs[attr]):
		return false
	S.sp = int(S.sp) - 1
	S.bought[k] = int(S.bought.get(k, 0)) + 1
	fx_note("%s → %d" % [world.SKILLS[k].name, level(k)])
	return true


# ---------- 흐름 ----------
func node() -> Dictionary:
	return story[S.node]


func go(id: String) -> void:
	assert(story.has(id), "노드 없음: " + id)
	var n: Dictionary = story[id]
	S.node = id
	S.visited[id] = visited(id) + 1
	if visited(id) == 1:
		apply(n.get("on"))
	for entry in n.text:
		add_line(resolve_line(entry))
	for p in n.get("passives", []):
		if level(p.s) + 6 >= int(p.dc):
			push("voice", "[color=%s][b][lb]%s %s: 성공][/b][/color] %s" % [skill_color(p.s), esc(world.SKILLS[p.s].name), diff_name(p.dc), esc(p.t)])
	if not n.get("ending", false):
		if int(S.hp) <= 0:
			go("dead_hp")
		elif int(S.morale) <= 0:
			go("dead_morale")


## 화면에 보일 선택지: [{opt, id, locked, lv}]
func visible_options() -> Array:
	var out := []
	var opts: Array = node().get("options", [])
	for i in opts.size():
		var o: Dictionary = opts[i]
		var id := "%s#%d" % [S.node, i]
		if o.has("req") and not o.req.all(func(f): return flag(f)):
			continue
		if o.has("not") and o["not"].any(func(f): return flag(f)):
			continue
		if o.has("cond") and not eval_cond(o.cond):
			continue
		if o.get("once", false) and S.used.has(id):
			continue
		var st := {"opt": o, "id": id, "locked": false, "lv": 0}
		if o.has("check"):
			var c = S.checks.get(id)
			st.lv = level(o.check.s)
			if c != null and c.ok:
				continue
			if c != null and o.check.get("red", false):
				continue
			if c != null and st.lv <= int(c.lvl):
				st.locked = true
		out.append(st)
	return out


func choose(st: Dictionary) -> void:
	var o: Dictionary = st.opt
	push("you", "[color=#8f877a][i]— %s[/i][/color]" % esc(o.t))
	S.used[st.id] = true
	tick()
	apply(o.get("fx"))
	if o.has("check"):
		var a := randi_range(1, 6)
		var b := randi_range(1, 6)
		var k: String = o.check.s
		var dc := int(o.check.dc)
		var lv := level(k)
		var ok := (a == 6 and b == 6) or (not (a == 1 and b == 1) and a + b + lv >= dc)
		S.checks[st.id] = {"ok": ok, "lvl": lv}
		events.append("roll_ok" if ok else "roll_no")
		var crit := " (결정적 성공)" if a == 6 and b == 6 else (" (결정적 실패)" if a == 1 and b == 1 else "")
		push("roll", "[font_size=15][color=#8f877a]%s (%d+%d+%d = %d / %d) [color=%s][b]%s%s[/b][/color][/color][/font_size]" % [
			skill_tag(k), a, b, lv, a + b + lv, dc, "#7fbf6a" if ok else "#b8322a", "성공" if ok else "실패", crit])
		go(o.ok if ok else o.no)
	else:
		go(o.go)


# ---------- 저장 ----------
func save_game() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(S))
	return true


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not data is Dictionary:
		return false
	S = data
	log_serial = 0
	return true
