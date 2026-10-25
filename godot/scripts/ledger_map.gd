## 명부 뒷장에 연필로 그린 약도. 그림 파일 없이 직접 그린다(가볍고, 상태에 따라 바로 바뀐다).
## 가 본 곳은 먹으로 진하게, 아는 곳은 흐리게, 창백이 먹은 곳은 종이째 하얗게. 지금 있는 곳에만 붉은 물감 한 방울.
class_name LedgerMap
extends Control

const PAPER := Color("#cdc3ad")
const RULE := Color("#b3a992")
const INK := Color("#2b2620")
const FAINT := Color("#8a806d")
const RIVER := Color("#4c5c68")
const PALE := Color("#f3f2ec")
const DROP := Color("#a8322a")

var game: Game
var page: Dictionary
var households: Array
var font: Font


func setup(g: Game, p: Dictionary, hh: Array, f: Font) -> void:
	game = g
	page = p
	households = hh
	font = f
	queue_redraw()


func _pt(x: float, y: float) -> Vector2:
	return Vector2(x * size.x, y * size.y)


func _place_state(pl: Dictionary) -> String:
	if _here(pl):
		return "visited"
	for n in pl.nodes:
		if game.visited(n) > 0:
			return "visited"
	if pl.get("hidden", false):
		return "hidden"
	if pl.has("known_if") and not game.eval_cond(pl.known_if):
		return "hidden"
	return "known"


func _here(pl: Dictionary) -> bool:
	var scene: String = game.node().scene
	for sc in pl.get("scenes", []):
		if scene.begins_with(sc):
			return true
	return false


## 창백이 먹은 깊이(화면 높이 비율). 3일째 보고서 뒤로는 물러남·확장에 따라 달라진다.
func _pale_depth() -> float:
	if game.flag("pale_receded"):
		return 0.07
	if game.flag("pale_expanded"):
		return 0.26
	return 0.12 + 0.01 * clampf(float(game.S.pale), 0.0, 6.0)


func _draw() -> void:
	if game == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	# 장부 괘선
	var y := 28.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), RULE, 1.0)
		y += 28.0
	draw_line(Vector2(54, 0), Vector2(54, size.y), Color(DROP, 0.25), 1.0)
	if page.get("lake", false):
		_draw_lake()
	if page.get("river", false):
		_draw_river()
	var by_id := {}
	for pl in page.places:
		by_id[pl.id] = pl
	for r in page.roads:
		var a: Dictionary = by_id[r[0]]
		var b: Dictionary = by_id[r[1]]
		var sa := _place_state(a)
		var sb := _place_state(b)
		if sa == "hidden" or sb == "hidden":
			continue
		var both := sa == "visited" and sb == "visited"
		_pencil_line(_pt(a.x, a.y), _pt(b.x, b.y), INK if both else FAINT, 2.0 if both else 1.0, not both)
	for eh in page.get("erased_houses", []):
		_draw_erased(eh)
	for pl in page.places:
		_draw_place(pl)
	if page.get("river", false) and not game.flag("pale_receded"):
		_draw_pale_creep()


func _draw_river() -> void:
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in 41:
		var t := i / 40.0
		var yy := 0.27 + 0.025 * sin(t * 7.0) + 0.012 * sin(t * 17.0)
		top.append(_pt(t, yy - 0.035))
		bot.append(_pt(t, yy + 0.02))
	draw_polyline(top, RIVER, 2.0)
	draw_polyline(bot, RIVER, 1.5)
	for i in 14:
		var t := 0.04 + i * 0.07
		var p := _pt(t, 0.27 + 0.025 * sin(t * 7.0) - 0.008)
		draw_line(p, p + Vector2(14, 0), Color(RIVER, 0.6), 1.0)
	_label(_pt(0.1, 0.335), "압 록 강", RIVER, 13)
	# 강 건너: 창백. 종이가 그 자리만 하얗다.
	var depth := _pale_depth()
	var poly := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0)])
	for i in range(30, -1, -1):
		var t := i / 30.0
		poly.append(_pt(t, depth + 0.02 * sin(t * 11.0 + 1.3) + 0.012 * sin(t * 29.0)))
	draw_colored_polygon(poly, PALE)
	_label(_pt(0.58, depth * 0.45), "(그릴 것이 없다)", Color(FAINT, 0.7), 12)


## 확장 분기에서는 창백이 마을 쪽으로 혀를 내민다.
func _draw_pale_creep() -> void:
	if not game.flag("pale_expanded"):
		return
	for c in [Vector2(0.35, 0.3), Vector2(0.62, 0.34), Vector2(0.86, 0.28)]:
		var poly := PackedVector2Array()
		for i in 18:
			var a := i / 18.0 * TAU
			var r := 0.05 + 0.015 * sin(a * 3.0 + c.x * 9.0)
			poly.append(_pt(c.x + cos(a) * r * 0.8, c.y + sin(a) * r))
		draw_colored_polygon(poly, PALE)


func _draw_lake() -> void:
	var poly := PackedVector2Array()
	for i in 32:
		var a := i / 32.0 * TAU
		poly.append(_pt(0.78 + cos(a) * 0.17 * (1.0 + 0.08 * sin(a * 3.0)), 0.8 + sin(a) * 0.13))
	poly.append(poly[0])
	draw_polyline(poly, RIVER, 2.0)
	_label(_pt(0.71, 0.73), "삼지연 못", RIVER, 13)


func _draw_erased(eh: Dictionary) -> void:
	var hh: Dictionary = households[int(eh.household)]
	var c := _pt(eh.x, eh.y)
	var restored := game.eval_cond(hh.restore_if)
	if restored:
		_house(c, INK, 1.5)
		_label(c + Vector2(12, 5), hh.head, INK, 13)
	else:
		draw_circle(c, 15.0, PALE)
		_house(c, Color(FAINT, 0.35), 1.0)
		_label(c + Vector2(12, 5), "이사 감", Color(FAINT, 0.8), 12)


func _draw_place(pl: Dictionary) -> void:
	var st := _place_state(pl)
	if st == "hidden":
		return
	var c := _pt(pl.x, pl.y)
	var col := INK if st == "visited" else FAINT
	if st == "visited":
		draw_circle(c, 6.0, INK)
	else:
		draw_arc(c, 6.0, 0, TAU, 16, FAINT, 1.0)
	var w := font.get_string_size(pl.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var at := c + Vector2(10, 5)
	if at.x + w > size.x - 6:
		at.x = c.x - 10 - w
	_label(at, pl.name, col, 15)
	if _here(pl):
		# 지금 있는 곳: 붉은 물감 한 방울과 위성 방울
		draw_circle(c + Vector2(-1, -1), 9.0, Color(DROP, 0.85))
		draw_circle(c + Vector2(9, -8), 2.5, Color(DROP, 0.7))
		draw_circle(c + Vector2(-8, 7), 1.8, Color(DROP, 0.6))


func _house(c: Vector2, col: Color, w: float) -> void:
	var pts := PackedVector2Array([c + Vector2(-7, 6), c + Vector2(-7, -2), c + Vector2(0, -8), c + Vector2(7, -2), c + Vector2(7, 6), c + Vector2(-7, 6)])
	draw_polyline(pts, col, w)


func _pencil_line(a: Vector2, b: Vector2, col: Color, w: float, dashed: bool) -> void:
	if dashed:
		draw_dashed_line(a, b, col, w, 6.0)
	else:
		draw_line(a, b, col, w)


func _label(at: Vector2, t: String, col: Color, sz: int) -> void:
	# 글자 밑의 선을 종이색으로 지워 읽히게 한다
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	draw_rect(Rect2(at + Vector2(-2, -sz * 0.95), Vector2(w + 4, sz * 1.2)), Color(PAPER, 0.85))
	draw_string(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)
