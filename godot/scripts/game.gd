## 게임 상태와 규칙. UI와 분리되어 있어 헤드리스 테스트에서도 그대로 쓴다.
class_name Game
extends RefCounted

const SAVE_PATH := "user://save.json"   # 예전 한 칸짜리 보관 파일. 처음 열 때 1번 칸으로 옮긴다.
const SLOTS := ["auto", "1", "2", "3"]   # auto: 자동 보관
const LOG_LIMIT := 400
const ATTR_COLORS := {"int": "#5fb0d0", "psy": "#a68be0", "fys": "#d0625a", "mot": "#d8b54c"}
const PALE_STAGES := ["희미함", "번짐", "침식", "잠식", "백색"]

var world: Dictionary
var story: Dictionary
var S: Dictionary = {}          # 저장되는 상태 전체
var log_serial := 0             # 지금까지 추가된 로그 수 (UI 증분 렌더링용)
var events: Array[String] = []  # 이번 행동에서 일어난 일 (소리·화면 효과용). UI가 비운다.
var _expr_cache := {}
var errors: Array[String] = []   # 해석하지 못한 조건식 (테스트가 확인한다)


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
		"pale": 0, "ticks": 0, "day": 1, "day_tick": 0, "names": [], "ws": 0, "rep": {},
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


## 가지고 있는 장비의 기술 보너스
func item_bonus(k: String) -> int:
	var b := 0
	for id in world.ITEMS:
		var it: Dictionary = world.ITEMS[id]
		if it.has("bonus") and flag("item_" + id):
			b += int(it.bonus.get(k, 0))
	return b


func level(k: String) -> int:
	var attr: String = world.SKILLS[k].attr
	return maxi(0, int(S.attrs[attr]) + int(S.bought.get(k, 0)) + thought_bonus(k) + item_bonus(k))


func skill_color(k: String) -> String:
	return ATTR_COLORS[world.SKILLS[k].attr]


## 난이도 이름. 표에 없는 값(예: 11)은 그보다 낮은 가장 가까운 단계 이름을 쓴다.
func diff_name(dc) -> String:
	var best := ""
	var best_v := -1
	for k in world.DIFF:
		var v := int(k)
		if v <= int(dc) and v > best_v:
			best_v = v
			best = world.DIFF[k]
	return best if best != "" else str(int(dc))


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
	return bool(S.flags.get(n, false))


## 소지품 개수 (item_<id> 플래그에 개수를 저장한다)
func item_count(k: String) -> int:
	var v = S.flags.get("item_" + k, 0)
	return int(v) if (v is int or v is float) else (1 if v else 0)


## 세력 호감도 (조건식에서 rep("bear") 형태로 쓴다)
func rep(k: String) -> int:
	return int(S.get("rep", {}).get(k, 0))


func visited(n: String) -> int:
	return int(S.visited.get(n, 0))


func names_count() -> int:
	return S.names.size()


func has_name(n: String) -> bool:
	return n in S.names


## 청수리의 창백 점수. 3일째 밤에 물러남(≥3)과 확장(<3)을 가른다.
func ws() -> int:
	return int(S.get("ws", 0))


func eval_cond(src: String) -> bool:
	var e: Expression = _expr_cache.get(src)
	if e == null:
		e = Expression.new()
		if e.parse(src) != OK:
			_cond_error("조건식 파싱 실패: %s (%s)" % [src, e.get_error_text()])
			return false
		_expr_cache[src] = e
	var r = e.execute([], self, true)
	if e.has_execute_failed():
		_cond_error("조건식 실행 실패: " + src)
		return false
	return bool(r)


func _cond_error(msg: String) -> void:
	if not msg in errors:
		errors.append(msg)
		push_error(msg)


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
		S.speaker = m.get_string(1)
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
	if fx.has("ws"):
		S.ws = ws() + int(fx.ws)
	for k in _as_list(fx.get("item")):
		if world.ITEMS[k].get("unique", false) and item_count(k) > 0:
			continue
		S.flags["item_" + k] = item_count(k) + 1
		fx_note("소지품: " + world.ITEMS[k].name)
		if k == "ledger":
			sys("— 왼쪽 「명부」를 눌러 펼쳐 볼 수 있다 —")
	for k in _as_list(fx.get("unitem")):
		var n := item_count(k) - 1
		if n > 0:
			S.flags["item_" + k] = n
		else:
			S.flags.erase("item_" + k)
	if fx.has("rep"):
		if not S.has("rep"):
			S.rep = {}
		for k in fx.rep:
			var v := int(fx.rep[k])
			S.rep[k] = rep(k) + v
			if v != 0:
				fx_note("%s 호감도 %+d" % [world.FACTIONS[k].name, v])
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
	S.speaker = ""
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


## 인물 화면의 추가 칸: [[제목, [줄...]]]  소지품 · 동행 · 창백 상황
func sheet_extras() -> Array:
	var out := []
	var reps := []
	for k in world.FACTIONS:
		if S.get("rep", {}).has(k):
			reps.append("%s  %d\n%s" % [world.FACTIONS[k].name, rep(k), world.FACTIONS[k].desc])
	if reps.size() > 0:
		out.append(["세력 호감도", reps])
	var comp := []
	if flag("choi_with"):
		comp.append("최경철 — 검열국 중좌")
	if flag("met_mun") and flag("pale_receded"):
		comp.append("문봉식 — 협궤 운전수")
	if flag("met_yoon") and flag("pale_expanded"):
		comp.append("윤해란 — 중앙당 지도원")
	if comp.size() > 0:
		out.append(["동행", comp])
	if flag("report_done"):
		out.append(["창백 상황", ["청수리: " + ("물러남" if ws() >= 3 else "확장")]])
	return out


## 소지품 목록: [{id, name, desc, count, effect, usable}]
func items_list() -> Array:
	var out := []
	var names := {"hp": "체력", "morale": "사기", "pale": "창백 노출"}
	for k in world.ITEMS:
		var n := item_count(k)
		if n <= 0:
			continue
		var it: Dictionary = world.ITEMS[k]
		var eff := []
		if it.has("use"):
			for e in it.use:
				eff.append("%s %+d" % [names[e], int(it.use[e])])
		elif it.has("bonus"):
			for e in it.bonus:
				eff.append("%s +%d" % [world.SKILLS[e].name, int(it.bonus[e])])
		out.append({"id": k, "name": it.name, "desc": it.desc, "count": n, "effect": ", ".join(eff), "usable": it.has("use")})
	return out


## 음식을 먹는다.
func use_item(k: String) -> void:
	var it: Dictionary = world.ITEMS.get(k, {})
	if not it.has("use") or item_count(k) <= 0:
		return
	push("you", "[color=#8f877a][i]— %s을(를) 먹는다.[/i][/color]" % esc(it.name))
	apply({"unitem": k})
	apply(it.use)


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
	elif o.go == "_return":
		close_ledger()
	else:
		go(o.go)


## 명부 창에서 명부 장면(lg_*)을 연다. 덮으면 원래 장면으로 돌아간다(본문을 다시 찍지 않는다).
## in_village: 지금 청수리 안에 있는가. 이름은 그 집 앞에서 불러야 한다.
func open_ledger(id: String, in_village: bool) -> void:
	if not str(S.node).begins_with("lg_"):
		S.ledger_from = S.node
	S.flags["lg_village"] = in_village
	sys("— 명부를 펼친다 —")
	go(id)


func close_ledger() -> void:
	S.node = S.get("ledger_from", "square")
	S.speaker = ""
	sys("— 명부를 덮는다 —")


# ---------- 저장 ----------
static func slot_path(slot: String) -> String:
	return "user://save_%s.json" % slot


## 예전 save.json을 1번 칸으로 옮긴다(이미 1번 칸이 있으면 그대로 둔다).
static func migrate_old_save() -> void:
	if FileAccess.file_exists(SAVE_PATH) and not FileAccess.file_exists(slot_path("1")):
		DirAccess.rename_absolute(SAVE_PATH, slot_path("1"))


func save_game(slot: String = "1") -> bool:
	S.saved_at = int(Time.get_unix_time_from_system())
	S.saved_scene = node().get("scene", "")
	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(S))
	f.close()   # 웹에서는 닫을 때 브라우저 저장소(IndexedDB)로 동기화된다
	return true


func load_game(slot: String = "1") -> bool:
	var data = read_slot(slot)
	if data.is_empty():
		return false
	S = data
	if not S.has("rep"):
		S.rep = {}
	log_serial = 0
	return true


static func read_slot(slot: String) -> Dictionary:
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}


## 칸 목록에 보여 줄 요약. 비어 있으면 빈 사전.
static func slot_info(slot: String) -> Dictionary:
	var d := read_slot(slot)
	if d.is_empty():
		return {}
	var t := int(d.get("saved_at", 0))
	var when := Time.get_datetime_string_from_unix_time(t + _tz_offset(), true).substr(5, 11) if t > 0 else ""
	return {"day": int(d.get("day", 1)), "scene": str(d.get("saved_scene", "")), "names": d.get("names", []).size(),
		"saved_at": t, "when": when.replace("T", " ")}


static func _tz_offset() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60


## 가장 최근에 보관된 칸(없으면 빈 문자열). 첫화면의 이어하기가 쓴다.
static func latest_slot() -> String:
	var best := ""
	var best_t := -1
	for slot in SLOTS:
		var info := slot_info(slot)
		if not info.is_empty() and int(info.saved_at) > best_t:
			best_t = int(info.saved_at)
			best = slot
	return best
