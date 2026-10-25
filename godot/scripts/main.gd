## 화면 구성과 입력. 규칙은 전부 Game이 맡는다.
extends Control

const C_BG := Color("#141312")
const C_PANEL := Color("#1d1b19")
const C_LINE := Color("#3a352f")
const C_INK := Color("#e4dccd")
const C_DIM := Color("#8f877a")
const C_OPT := Color("#d9c08a")
const C_HP := Color("#d0625a")
const C_MO := Color("#a68be0")

var game := Game.new()
var font_regular: Font = preload("res://fonts/NanumMyeongjo-Regular.ttf")
var font_bold: Font = preload("res://fonts/NanumMyeongjo-Bold.ttf")

var log_view: RichTextLabel
var opts_box: VBoxContainer
var opts_scroll: ScrollContainer
var scene_label: Label
var clock_label: Label
var hp_pips: HBoxContainer
var mo_pips: HBoxContainer
var pale_label: Label
var sheet_btn: Button
var thought_btn: Button
var modal: Control
var modal_body: VBoxContainer
var rendered_serial := 0
var option_buttons: Array[Button] = []


func _ready() -> void:
	theme = _make_theme()
	_build_layout()
	_open_start()


# ---------- 테마 ----------
func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font_regular
	t.default_font_size = 19
	t.set_color("font_color", "Label", C_INK)
	t.set_color("font_color", "Button", C_INK)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", C_DIM)
	t.set_color("default_color", "RichTextLabel", C_INK)
	t.set_font("bold_font", "RichTextLabel", font_bold)
	t.set_font("italics_font", "RichTextLabel", font_regular)
	t.set_constant("line_separation", "RichTextLabel", 6)
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, 0)
	flat.border_color = C_LINE
	flat.set_border_width_all(1)
	flat.set_content_margin_all(8)
	var hover := flat.duplicate()
	hover.border_color = C_INK
	for s in ["normal", "pressed", "disabled", "focus"]:
		t.set_stylebox(s, "Button", flat)
	t.set_stylebox("hover", "Button", hover)
	return t


func _opt_button_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


# ---------- 레이아웃 ----------
func _build_layout() -> void:
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	add_child(row)

	# 왼쪽 패널
	var side_bg := PanelContainer.new()
	var side_style := StyleBoxFlat.new()
	side_style.bg_color = Color("#1a1917")
	side_style.border_color = C_LINE
	side_style.border_width_right = 1
	side_style.set_content_margin_all(20)
	side_bg.add_theme_stylebox_override("panel", side_style)
	side_bg.custom_minimum_size.x = 300
	row.add_child(side_bg)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 12)
	side_bg.add_child(side)

	scene_label = Label.new()
	scene_label.add_theme_font_size_override("font_size", 26)
	scene_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(scene_label)
	clock_label = _dim_label(15)
	side.add_child(clock_label)
	hp_pips = _pip_row(side, "체력")
	mo_pips = _pip_row(side, "사기")
	pale_label = _dim_label(15)
	side.add_child(pale_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(spacer)
	sheet_btn = _side_button(side, "인물 · 기술", _open_sheet)
	thought_btn = _side_button(side, "사상함", _open_thoughts)
	_side_button(side, "저장", _on_save)
	_side_button(side, "불러오기", _on_load)
	_side_button(side, "새 게임", _open_start)

	# 오른쪽: 로그 + 선택지
	var main_col := VBoxContainer.new()
	main_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_col.add_theme_constant_override("separation", 0)
	row.add_child(main_col)

	var log_margin := MarginContainer.new()
	log_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side_name in ["left", "right"]:
		log_margin.add_theme_constant_override("margin_" + side_name, 36)
	log_margin.add_theme_constant_override("margin_top", 28)
	log_margin.add_theme_constant_override("margin_bottom", 12)
	main_col.add_child(log_margin)
	log_view = RichTextLabel.new()
	log_view.bbcode_enabled = true
	log_view.scroll_following = true
	log_view.selection_enabled = true
	log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_margin.add_child(log_view)

	var sep := ColorRect.new()
	sep.color = C_LINE
	sep.custom_minimum_size.y = 1
	main_col.add_child(sep)

	opts_scroll = ScrollContainer.new()
	opts_scroll.custom_minimum_size.y = 250
	opts_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_col.add_child(opts_scroll)
	var opts_margin := MarginContainer.new()
	opts_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side_name in ["left", "right"]:
		opts_margin.add_theme_constant_override("margin_" + side_name, 36)
	opts_margin.add_theme_constant_override("margin_top", 14)
	opts_margin.add_theme_constant_override("margin_bottom", 18)
	opts_scroll.add_child(opts_margin)
	opts_box = VBoxContainer.new()
	opts_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opts_margin.add_child(opts_box)

	_build_modal()


func _dim_label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_color_override("font_color", C_DIM)
	l.add_theme_font_size_override("font_size", size)
	return l


func _pip_row(parent: Control, title: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := _dim_label(16)
	l.text = title
	l.custom_minimum_size.x = 44
	h.add_child(l)
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 4)
	h.add_child(pips)
	parent.add_child(h)
	return pips


func _side_button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _build_modal() -> void:
	modal = ColorRect.new()
	modal.color = Color(0, 0, 0, 0.78)
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and game.has_game():
			_close_modal())
	add_child(modal)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(center)
	var panel := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = C_PANEL
	ps.border_color = C_LINE
	ps.set_border_width_all(1)
	ps.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", ps)
	panel.custom_minimum_size = Vector2(780, 560)
	center.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	modal_body = VBoxContainer.new()
	modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_body.add_theme_constant_override("separation", 8)
	scroll.add_child(modal_body)
	modal.hide()


# ---------- 렌더링 ----------
func _refresh() -> void:
	_render_log()
	_render_side()
	_render_options()


func _render_log() -> void:
	var entries: Array = game.S.log
	var fresh := game.log_serial - rendered_serial
	if rendered_serial == 0 or fresh > entries.size():
		log_view.clear()
		fresh = entries.size()
	for i in range(entries.size() - fresh, entries.size()):
		log_view.append_text(entries[i][1] + "\n\n")
	rendered_serial = game.log_serial


func _render_side() -> void:
	scene_label.text = game.node().scene
	clock_label.text = game.clock_text()
	_pips(hp_pips, int(game.S.hp), game.max_hp(), C_HP)
	_pips(mo_pips, int(game.S.morale), game.max_morale(), C_MO)
	pale_label.text = "창백 노출: %s\n기억한 이름: %d" % [game.pale_stage(), game.S.names.size()]
	var sp := int(game.S.sp)
	sheet_btn.text = "인물 · 기술" + (" (+%d)" % sp if sp > 0 else "")
	var t: Dictionary = game.S.thoughts
	thought_btn.text = "사상함" + (" (내면화 중)" if t.active != "" else (" (%d)" % t.known.size() if t.known.size() > 0 else ""))


func _pips(box: HBoxContainer, cur: int, mx: int, col: Color) -> void:
	for c in box.get_children():
		c.queue_free()
	for i in mx:
		var r := ColorRect.new()
		r.custom_minimum_size = Vector2(14, 14)
		r.color = col if i < cur else C_LINE
		box.add_child(r)


func _render_options() -> void:
	for c in opts_box.get_children():
		c.queue_free()
	option_buttons.clear()
	if game.node().get("ending", false):
		_add_option_button("— 새 게임 —", C_OPT, _open_start)
		return
	var k := 0
	for st in game.visible_options():
		k += 1
		var o: Dictionary = st.opt
		var text := "%d.  " % k
		var col := C_OPT
		if o.has("check"):
			var skill: String = o.check.s
			col = Color(game.skill_color(skill))
			var pct := "잠김" if st.locked else "%d%%" % Game.chance(st.lv, int(o.check.dc))
			text += "%s〔%s · %s %d · %s〕 " % ["● " if o.check.get("red", false) else "", game.world.SKILLS[skill].name, game.diff_name(o.check.dc), int(o.check.dc), pct]
		text += o.t
		var b := _add_option_button(text, col, game_choose.bind(st))
		if st.locked:
			b.disabled = true
			b.tooltip_text = "이 기술의 레벨이 오르면 다시 시도할 수 있다."
		elif o.has("check") and o.check.get("red", false):
			b.tooltip_text = "붉은 판정: 단 한 번의 기회."


func _add_option_button(text: String, col: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", col.lightened(0.4))
	var s := _opt_button_style()
	for name in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(name, s)
	b.pressed.connect(cb)
	opts_box.add_child(b)
	option_buttons.append(b)
	return b


func game_choose(st: Dictionary) -> void:
	game.choose(st)
	_refresh()
	opts_scroll.scroll_vertical = 0


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if modal.visible:
		if event.keycode == KEY_ESCAPE and game.has_game():
			_close_modal()
		return
	var n: int = event.keycode - KEY_1
	if n >= 0 and n < 9 and n < option_buttons.size() and not option_buttons[n].disabled:
		option_buttons[n].pressed.emit()


# ---------- 모달 ----------
func _open_modal() -> void:
	for c in modal_body.get_children():
		c.queue_free()
	if game.has_game():
		var close := Button.new()
		close.text = "닫기"
		close.size_flags_horizontal = Control.SIZE_SHRINK_END
		close.pressed.connect(_close_modal)
		modal_body.add_child(close)
	modal.show()


func _close_modal() -> void:
	modal.hide()


func _modal_title(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 26)
	modal_body.add_child(l)


func _modal_text(t: String, col: Color = C_DIM, size: int = 16) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	modal_body.add_child(l)
	return l


func _open_start() -> void:
	_open_modal()
	_modal_title("창백한 청수리")
	_modal_text("량강도 백수군 청수리. 압록강 너머가 사라졌다. 평양은 그것을 \"미제의 기상무기\"라 부른다. 당신은 조사를 위해 파견된 국가보위성 소좌다. 그리고 당신의 이름이 지워지고 있다.")
	_modal_text("출신을 고르시오", C_INK, 19)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	modal_body.add_child(grid)
	var archs: Array = game.world.ARCHETYPES
	for i in archs.size():
		var a: Dictionary = archs[i]
		var stats := []
		for k in ["int", "psy", "fys", "mot"]:
			stats.append("%s %d" % [game.world.ATTRS[k].name, int(a.attrs[k])])
		var b := Button.new()
		b.text = "%s\n%s\n%s" % [a.name, a.desc, " · ".join(stats)]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(355, 120)
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(_start_new.bind(i))
		grid.add_child(b)
	_modal_text("판정: 2d6 + 기술 레벨 ≥ 난이도. 흰 판정은 기술이 오르면 재시도 가능, ● 붉은 판정은 단 한 번.", C_DIM, 14)


func _start_new(i: int) -> void:
	game.new_game(i)
	rendered_serial = 0
	_close_modal()
	_refresh()


func _open_sheet() -> void:
	if not game.has_game():
		return
	_open_modal()
	_modal_title("보위원 소좌 [이름 없음]")
	_modal_text("기술 점수: %d · 각 기술은 속성 값만큼 추가로 올릴 수 있다." % int(game.S.sp))
	if game.S.names.size() > 0:
		_modal_text("수첩 — 기억한 이름: " + " · ".join(game.S.names), C_INK, 15)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	modal_body.add_child(grid)
	for a in ["int", "psy", "fys", "mot"]:
		var col := VBoxContainer.new()
		col.custom_minimum_size.x = 350
		grid.add_child(col)
		var head := Label.new()
		head.text = "%s %d" % [game.world.ATTRS[a].name, int(game.S.attrs[a])]
		head.add_theme_color_override("font_color", Color(Game.ATTR_COLORS[a]))
		head.add_theme_font_size_override("font_size", 20)
		col.add_child(head)
		for k in game.world.SKILLS:
			var sk: Dictionary = game.world.SKILLS[k]
			if sk.attr != a:
				continue
			var row := HBoxContainer.new()
			col.add_child(row)
			var l := Label.new()
			var tb := game.thought_bonus(k)
			l.text = "%s %d%s\n%s" % [sk.name, game.level(k), (" (%+d 사상)" % tb) if tb != 0 else "", sk.desc]
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.add_theme_font_size_override("font_size", 15)
			row.add_child(l)
			if int(game.S.sp) > 0 and int(game.S.bought.get(k, 0)) < int(game.S.attrs[a]):
				var b := Button.new()
				b.text = "+"
				b.pressed.connect(func():
					game.buy(k)
					_open_sheet()
					_refresh())
				row.add_child(b)


func _open_thoughts() -> void:
	if not game.has_game():
		return
	_open_modal()
	_modal_title("사상함")
	_modal_text("생각을 품고 있으면 선택을 할 때마다 내면화가 진행된다. 한 번에 하나만.")
	var t: Dictionary = game.S.thoughts
	if t.active != "":
		_thought_card(t.active, "active")
	for id in t.known:
		if id != t.active:
			_thought_card(id, "known")
	if t.done.size() > 0:
		_modal_text("내면화된 사상", C_INK, 19)
		for id in t.done:
			_thought_card(id, "done")
	if t.active == "" and t.known.is_empty() and t.done.is_empty():
		_modal_text("아직 품은 사상이 없다. 생각은 위험한 곳에서 온다.", C_INK)


func _thought_card(id: String, state: String) -> void:
	var th: Dictionary = game.world.THOUGHTS[id]
	var bonus := []
	for k in th.bonus:
		bonus.append("%s %+d" % [game.world.SKILLS[k].name, int(th.bonus[k])])
	_modal_text("「%s」" % th.name, C_INK, 18)
	_modal_text(th.a if state == "done" else th.q, C_DIM, 15)
	_modal_text("효과: %s · 내면화 %d턴" % [", ".join(bonus), int(th.time)], C_DIM, 14)
	if state == "active":
		_modal_text("내면화 중… %d/%d" % [int(game.S.thoughts.progress), int(th.time)], Color("#dfe3e3"), 14)
	elif state == "known" and game.S.thoughts.active == "":
		var b := Button.new()
		b.text = "내면화한다"
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.pressed.connect(func():
			game.internalize(id)
			_open_thoughts()
			_refresh())
		modal_body.add_child(b)


# ---------- 저장 ----------
func _on_save() -> void:
	if not game.has_game():
		return
	game.sys("— 저장됨 —" if game.save_game() else "— 저장 실패 —")
	_render_log()


func _on_load() -> void:
	if game.load_game():
		rendered_serial = 0
		game.sys("— 불러옴 —")
		_close_modal()
		_refresh()
	elif game.has_game():
		game.sys("— 저장된 게임 없음 —")
		_render_log()
