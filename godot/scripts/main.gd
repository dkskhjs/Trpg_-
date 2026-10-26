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
const C_HEAD := Color("#e8c890")   # 제목·항목 이름: 굵게, 금빛
## 대사하는 인물 → [초상화 파일(art/portraits/<id>.webp), 이름표, 물감 방울 자리].
## 초상화는 흑백이고, 방울 자리(x, y, 반지름 — 그림 기준 0~1)에만 원래 색이 돌아온다.
## 위치는 tools/tone_preview.py로 미리 본다(같은 공식).
const PORTRAITS := {
	"": ["hero", "보위원 소좌 [이름 없음]", [Vector3(0.60, 0.42, 0.09), Vector3(0.86, 0.80, 0.09)]],
	"박순녀": ["park", "박순녀 — 인민반장", [Vector3(0.94, 0.89, 0.12), Vector3(0.30, 0.50, 0.15), Vector3(0.56, 0.50, 0.08)]],
	"정명수": ["myeongsu", "정명수 — 하전사", [Vector3(0.08, 0.34, 0.11), Vector3(0.56, 0.46, 0.10), Vector3(0.78, 0.70, 0.08)]],
	"하전사": ["myeongsu", "정명수 — 하전사", [Vector3(0.08, 0.34, 0.11), Vector3(0.56, 0.46, 0.10), Vector3(0.78, 0.70, 0.08)]],
	"오영희": ["oh", "오영희 — 기상관측원", [Vector3(0.80, 0.64, 0.16), Vector3(0.52, 0.49, 0.09), Vector3(0.88, 0.28, 0.07)]],
	"고양이": ["cat", "고양이 — 밀수꾼", [Vector3(0.80, 0.86, 0.17), Vector3(0.52, 0.48, 0.10)]],
	"최경철": ["choi", "최경철 — 검열국 중좌", []],
	"노인": ["elder", "묘지기 노인", []],
	"철도원": ["mun", "문봉식 — 협궤 운전수", [Vector3(0.68, 0.53, 0.13), Vector3(0.50, 0.31, 0.09), Vector3(0.62, 0.11, 0.06)]],
	"문봉식": ["mun", "문봉식 — 협궤 운전수", [Vector3(0.68, 0.53, 0.13), Vector3(0.50, 0.31, 0.09), Vector3(0.62, 0.11, 0.06)]],
	"윤해란": ["yoon", "윤해란 — 중앙당 지도원", [Vector3(0.76, 0.65, 0.07), Vector3(0.50, 0.27, 0.11), Vector3(0.65, 0.73, 0.06)]],
	"리철": ["cheol", "리철 — 소년단원", [Vector3(0.42, 0.51, 0.15), Vector3(0.72, 0.68, 0.12), Vector3(0.50, 0.28, 0.08)]],
	"김선희": ["kimsh", "김선희 — 혁명전적지 해설강사", [Vector3(0.88, 0.36, 0.07), Vector3(0.54, 0.30, 0.07), Vector3(0.52, 0.48, 0.11), Vector3(0.40, 0.80, 0.10)]],
	"허명진": ["heo", "허명진 — 창백 연구소 연구사", []],
	"도학수": ["do", "도학수 — 곰쫓사 조사단장", []],
	"곽만석": ["kwak", "곽만석 — 백두산 포수", []],
	"서은하": ["seo", "서은하 — 곰쫓사 생물학 연구원", []],
	"강동혁": ["kang", "강동혁 — 정리반장", []],
	"백순자": ["baek", "백순자 — 흰 길 상단", []],
}
## 사람 대신 사물을 보여주는 장면: 노드 id → PORTRAITS와 같은 형식. 화자보다 먼저 적용한다.
const NODE_PORTRAITS := {
	"portrait": ["leader_portrait", "벽의 초상화 — 얼굴이 없다", [Vector3(0.18, 0.20, 0.14), Vector3(0.86, 0.24, 0.12), Vector3(0.20, 0.80, 0.12), Vector3(0.84, 0.82, 0.14)]],
}
const NODE_PORTRAIT_ALIASES := {"portrait_ignore": "portrait", "portrait_panic": "portrait", "portrait_wipe": "portrait"}

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
var ledger_btn: Button
var ledger_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ledger.json"))
var ledger_tab := "people"
var dossier: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dossier.json"))
var modal: Control
var modal_body: VBoxContainer
var rendered_serial := 0
var option_buttons: Array[Button] = []
var audio: AudioDirector
var pale_fx: ShaderMaterial
var portrait: TextureRect
var portrait_caption: Label
var portrait_id := ""
var backgrounds: Array[TextureRect] = []
var bg_active := 0
var bg_id := ""
var bg_shade: ColorRect
var vista_fx: ShaderMaterial
## 창백이 그려진 풍경: 전용 셰이더를 씌운다. 처음 볼 때는 막을 걷어 풍경을 보여준 뒤(VISTA_REVEAL초)
## 글을 읽을 수 있을 만큼 다시 어둡게 한다. 값은 그 뒤의 막 농도.
const VISTAS := {}   # 예: {"river_beyond": 0.66} — 지금은 쓰는 풍경 없음
const VISTA_REVEAL := 2.2
## 배경별 막 농도(기본 0.8). 흐릿한 실사진은 막을 옅게 해야 풍경이 보인다.
const SHADE := {"river": 0.6}
var typing_delay := 0.0   # 다음 타자 효과를 시작하기 전 기다릴 시간
var typing: Tween
var pale_overlay: ColorRect
var shown_entries := 0   # 로그 창에 지금 그려진 항목 수
const LOG_VIEW_KEEP := 150   # 로그 창에는 최근 항목만 남긴다(저장 기록은 그대로)
var slow_checks := 0   # 초당 프레임이 낮게 나온 연속 횟수
var fps_timer := 0.0
var settings := Settings.load_or_default()
var title: TitleScreen
var instant_log := false


func _ready() -> void:
	theme = _make_theme()
	_build_layout()
	audio = AudioDirector.new()
	add_child(audio)
	audio.set_volumes(settings.master, settings.music)
	audio.set_muted(settings.muted)
	_show_title()


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

	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(260, 300)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var tone := ShaderMaterial.new()
	tone.shader = preload("res://shaders/portrait.gdshader")
	portrait.material = tone
	side.add_child(portrait)
	portrait_caption = _dim_label(14)
	side.add_child(portrait_caption)

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
	# 명부: 얻은 뒤에만 보인다. 이 놀이의 중심 물건이라 따로 크게 둔다.
	ledger_btn = _side_button(side, "명부 펼치기", func(): _open_ledger(ledger_tab))
	ledger_btn.add_theme_color_override("font_color", C_HEAD)
	ledger_btn.add_theme_font_override("font", font_bold)
	ledger_btn.hide()
	var buttons := GridContainer.new()
	buttons.columns = 2
	buttons.add_theme_constant_override("h_separation", 6)
	buttons.add_theme_constant_override("v_separation", 6)
	side.add_child(buttons)
	sheet_btn = _side_button(buttons, "인물 · 기술", _open_sheet)
	thought_btn = _side_button(buttons, "사상함", _open_thoughts)
	_side_button(buttons, "보관하기", _on_save)
	_side_button(buttons, "불러오기", _on_load)
	_side_button(buttons, "설정", _open_settings)
	_side_button(buttons, "첫화면으로", _show_title)

	# 오른쪽: 로그 + 선택지
	# 본문 뒤에 장소 배경 두 장(교차 페이드용)과 글자를 읽을 수 있게 하는 어두운 막
	var right := Control.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.clip_contents = true
	row.add_child(right)
	for i in 2:
		var layer := TextureRect.new()
		layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		layer.modulate.a = 0.0
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		right.add_child(layer)
		backgrounds.append(layer)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(C_BG, 0.8)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(shade)
	bg_shade = shade
	vista_fx = ShaderMaterial.new()
	vista_fx.shader = preload("res://shaders/bg_pale.gdshader")
	var main_col := VBoxContainer.new()
	main_col.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_col.add_theme_constant_override("separation", 0)
	right.add_child(main_col)

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
	# 모양을 한 번만 잡고 보이는 글자 수만 바꾼다. 매 프레임 전체를 다시 배치하지 않아 긴 로그에서도 가볍다.
	log_view.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	log_view.gui_input.connect(_skip_on_click)
	log_margin.add_child(log_view)

	var sep := ColorRect.new()
	sep.color = C_LINE
	sep.custom_minimum_size.y = 1
	main_col.add_child(sep)

	opts_scroll = ScrollContainer.new()
	opts_scroll.custom_minimum_size.y = 250
	opts_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	opts_scroll.gui_input.connect(_skip_on_click)
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

	title = TitleScreen.new()
	add_child(title)
	title.new_game.connect(_open_start)
	title.continue_game.connect(_on_continue)
	title.open_settings.connect(_open_settings)
	title.open_credits.connect(_open_credits)
	title.quit_game.connect(func(): get_tree().quit())
	_build_modal()
	_build_pale_overlay()


## 화면 맨 위에 덮는 창백 셰이더. 입력은 그대로 통과시킨다.
func _build_pale_overlay() -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pale_fx = ShaderMaterial.new()
	pale_fx.shader = preload("res://shaders/pale.gdshader")
	for param in ["intensity", "edge", "pulse"]:
		pale_fx.set_shader_parameter(param, 0.0)
	overlay.material = pale_fx
	add_child(overlay)
	pale_overlay = overlay
	overlay.hide()


## 플레이 중 2초마다 초당 프레임을 보고, 세 번 연속 25 아래면 한 번만 가벼운 화면으로 바꾼다.
func _process(delta: float) -> void:
	if settings.lite or settings.lite_auto_done or not game.has_game() or title.visible:
		return
	fps_timer += delta
	if fps_timer < 2.0:
		return
	fps_timer = 0.0
	slow_checks = slow_checks + 1 if Engine.get_frames_per_second() < 25 else 0
	if slow_checks >= 3:
		settings.lite = true
		settings.lite_auto_done = true
		settings.save()
		_update_overlay_visibility()
		for b in backgrounds:
			b.material = null
		game.sys("— 화면이 느려 가벼운 화면으로 바꿨습니다. 설정에서 되돌릴 수 있습니다 —")
		_render_log()


## 창백 효과가 거의 없거나 가벼운 화면이면 화면 전체 셰이더를 끈다(화면 복사 비용이 크다).
func _update_overlay_visibility() -> void:
	var sum := 0.0
	for param in ["intensity", "edge", "pulse"]:
		sum += float(pale_fx.get_shader_parameter(param))
	pale_overlay.visible = sum > 0.01 and not settings.lite


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
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _build_modal() -> void:
	modal = ColorRect.new()
	modal.color = Color(0, 0, 0, 0.78)
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and modal.get_meta("closable", false):
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
	_render_side()   # 배경이 먼저 바뀌어야 풍경 연출에 맞춰 글을 늦출 수 있다
	_render_log()
	_render_options()
	_update_atmosphere()


## 소리와 셰이더를 현재 상태에 맞춘다.
func _update_atmosphere() -> void:
	var scene: String = game.node().scene
	var node_id: String = game.S.node
	if scene == "명부" and game.story.has(game.S.get("ledger_from", "")):
		# 명부를 보는 동안에는 펼치기 전 장소의 소리를 그대로 둔다
		node_id = game.S.ledger_from
		scene = game.story[node_id].scene
	var ending: bool = game.node().get("ending", false)
	var pale := game.pale_intensity()
	audio.update(scene, node_id, int(game.S.day), ending, pale, game.minutes())
	audio.play_events(game.events)
	var k := settings.pale_strength
	vista_fx.set_shader_parameter("strength", k)
	vista_fx.set_shader_parameter("pale", pale)
	_tween_param("intensity", clampf((pale + (0.5 if ending and "창백" in scene else 0.0)) * k, 0.0, 1.0), 2.0)
	_tween_param("edge", AudioDirector.edge_for(scene) * k, 2.0)
	if "pale_up" in game.events:
		pale_fx.set_shader_parameter("pulse", 1.0)
		_tween_param("pulse", 0.0, 1.8)
	game.events.clear()


func _tween_param(param: String, to: float, secs: float) -> void:
	var from: float = pale_fx.get_shader_parameter(param)
	create_tween().tween_method(func(v):
		pale_fx.set_shader_parameter(param, v)
		_update_overlay_visibility(), from, to, secs)




## 새로 붙은 로그만 타자기처럼 한 글자씩 드러낸다. 끝날 때까지 선택지는 숨긴다.
func _render_log() -> void:
	var entries: Array = game.S.log
	var fresh := game.log_serial - rendered_serial
	if rendered_serial == 0 or fresh > entries.size() or shown_entries + fresh > LOG_VIEW_KEEP + 50:
		# 처음부터 다시 그린다: 새 항목 앞에 최근 LOG_VIEW_KEEP개만
		fresh = mini(fresh, entries.size())
		log_view.clear()
		var start := maxi(0, entries.size() - fresh - LOG_VIEW_KEEP)
		for i in range(start, entries.size() - fresh):
			log_view.append_text(entries[i][1] + "\n\n")
		shown_entries = entries.size() - fresh - start
	var before := log_view.get_total_character_count()
	for i in range(entries.size() - fresh, entries.size()):
		log_view.append_text(entries[i][1] + "\n\n")
	shown_entries += fresh
	rendered_serial = game.log_serial
	var after := log_view.get_total_character_count()
	if typing:
		typing.kill()
	if instant_log or after <= before:
		instant_log = false
		_finish_typing()
		return
	log_view.visible_characters = before
	opts_box.visible = false
	typing = create_tween()
	if typing_delay > 0.0:
		typing.tween_interval(typing_delay)
		typing_delay = 0.0
	typing.tween_property(log_view, "visible_characters", after, (after - before) / settings.text_speed)
	typing.finished.connect(_finish_typing)


func _finish_typing() -> void:
	if typing:
		typing.kill()
		typing = null
	log_view.visible_characters = -1
	opts_box.visible = true


func _is_typing() -> bool:
	return typing != null and typing.is_running()


func _skip_on_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _is_typing():
		_finish_typing()


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
	ledger_btn.visible = game.item_count("ledger") > 0
	_show_portrait(game.S.get("speaker", ""), game.S.node)
	_show_background(background_for(game.node().scene, int(game.S.day)))


## 장면 이름 → 배경(art/scenes/<id>.webp). 그림이 없는 장소는 빈 문자열(어두운 바탕).
## "keep"이면 지금 배경을 유지한다(동행 대화처럼 장소가 바뀌지 않는 장면).
static func background_for(scene: String, day: int) -> String:
	if "동행" in scene or scene == "명부":
		return "keep"
	if "구류실" in scene or "결말" in scene or "어둠" in scene:
		return ""
	if "기념비 광장" in scene:
		return "monument"
	if "답사숙영소" in scene:
		return "pioneer_camp"
	if "연구소 천막" in scene:
		return "lab_tent"
	if "곰쫓사" in scene or "곰 발자국" in scene:
		return "bear_camp"
	if "정리반 지휘소" in scene:
		return "purge_post"
	if "흰 길 상단" in scene:
		return "caravan_ice"
	if "삼지연" in scene:
		return "samjiyon"
	if "협궤 철길" in scene:
		return "rail"
	if "하얀 길" in scene:
		return "jeep_road"
	if "보천" in scene:
		return "bocheon"
	if "초대소" in scene:
		return "inn_night" if "밤" in scene else "inn"
	if "궐기대회" in scene:
		return "rally"
	if "경계" in scene:
		return "edge"
	if "압록강" in scene or "창백의 가장자리" in scene:
		return "river"
	if "관측소" in scene:
		return "station"
	if "광장" in scene or "군용 트럭" in scene or "박순녀의 집 앞" in scene:
		return "square_pale" if day >= 3 else "square"
	if "박순녀의 집" in scene:
		return "park_home"
	if "장마당" in scene:
		return "market"
	if "공동묘지" in scene:
		return "graves"
	return ""


func _show_background(id: String) -> void:
	if id == bg_id or id == "keep":
		return
	bg_id = id
	var path := "res://art/scenes/%s.webp" % id
	var old := backgrounds[bg_active]
	bg_active = 1 - bg_active
	var nxt := backgrounds[bg_active]
	var tw := create_tween().set_parallel()
	tw.tween_property(old, "modulate:a", 0.0, 1.2)
	nxt.material = vista_fx if VISTAS.has(id) and not settings.lite else null
	if VISTAS.has(id):
		# 막을 걷어 풍경을 보여주고, 잠시 뒤 다시 내린다. 글은 그동안 기다린다.
		var reveal := create_tween()
		reveal.tween_property(bg_shade, "color:a", 0.12, 1.0)
		reveal.tween_interval(VISTA_REVEAL - 1.0)
		reveal.tween_property(bg_shade, "color:a", VISTAS[id], 1.4)
		typing_delay = VISTA_REVEAL
	else:
		tw.tween_property(bg_shade, "color:a", SHADE.get(id, 0.8), 1.2)
	if id != "" and ResourceLoader.exists(path):
		nxt.texture = load(path)
		tw.tween_property(nxt, "modulate:a", 1.0, 1.2)


## 이 장면에서 마지막으로 말한 인물의 초상화. 확성기·라디오처럼 초상화가 없는 목소리면 주인공.
func _show_portrait(speaker: String, node_id: String = "") -> void:
	var key: String = NODE_PORTRAIT_ALIASES.get(node_id, node_id)
	var entry: Array = NODE_PORTRAITS[key] if NODE_PORTRAITS.has(key) else PORTRAITS.get(speaker, PORTRAITS[""])
	var path := "res://art/portraits/%s.webp" % entry[0]
	if not ResourceLoader.exists(path):
		entry = PORTRAITS[""]
		path = "res://art/portraits/hero.webp"
	var tone: ShaderMaterial = portrait.material
	tone.set_shader_parameter("pale", game.pale_intensity())
	portrait_caption.text = _hero_title() if entry[0] == "hero" else entry[1]
	if entry[0] == portrait_id:
		return
	portrait_id = entry[0]
	var spots: Array = entry[2]
	var packed := PackedVector3Array(spots)
	packed.resize(4)
	tone.set_shader_parameter("spots", packed)
	tone.set_shader_parameter("spot_count", spots.size())
	portrait.texture = load(path)
	portrait.modulate.a = 0.0
	create_tween().tween_property(portrait, "modulate:a", 1.0, 0.6)


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
	audio.click()
	game.choose(st)
	_refresh()
	opts_scroll.scroll_vertical = 0


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if modal.visible:
		if event.keycode == KEY_ESCAPE and modal.get_meta("closable", false):
			_close_modal()
		return
	if _is_typing():
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER] or (event.keycode >= KEY_1 and event.keycode <= KEY_9):
			_finish_typing()
		return
	var n: int = event.keycode - KEY_1
	if n >= 0 and n < 9 and n < option_buttons.size() and not option_buttons[n].disabled:
		option_buttons[n].pressed.emit()


# ---------- 모달 ----------
## closable: 1이면 닫기 단추와 바깥 누르기로 닫힌다. -1이면 판이 진행 중일 때만.
func _open_modal(closable: int = -1) -> void:
	for c in modal_body.get_children():
		c.queue_free()
	var can_close := game.has_game() if closable < 0 else closable == 1
	modal.set_meta("closable", can_close)
	if can_close:
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
	l.add_theme_font_override("font", font_bold)
	l.add_theme_font_size_override("font_size", 26)
	modal_body.add_child(l)


## 창 안의 소제목 (예: 소지품, 세력 호감도)
func _modal_heading(t: String) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	modal_body.add_child(gap)
	modal_body.add_child(_heading_label(t, C_HEAD, 20))


func _heading_label(t: String, col: Color = C_HEAD, size: int = 17) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", font_bold)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _desc_label(t: String, size: int = 14) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", C_DIM)
	return l


## 항목 하나: 굵은 이름 + 흐린 설명
func _entry(title_text: String, desc: String, col: Color = C_HEAD, size: int = 17) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_heading_label(title_text, col, size))
	if desc != "":
		box.add_child(_desc_label(desc))
	return box


func _modal_text(t: String, col: Color = C_DIM, size: int = 16) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	modal_body.add_child(l)
	return l


func _open_start() -> void:
	_open_modal(1)
	_modal_title("새놀이")
	_modal_text("량강도 백수군 청수리. 압록강 너머가 사라졌다. 평양은 그것을 \"미제의 기상무기\"라 부른다. 당신은 조사를 위해 파견된 국가보위성 소좌다. 그리고 당신의 이름이 지워지고 있다.")
	_modal_heading("출신을 고르시오")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	modal_body.add_child(grid)
	var archs: Array = game.world.ARCHETYPES
	for i in archs.size():
		var a: Dictionary = archs[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(355, 130)
		b.pressed.connect(_start_new.bind(i))
		grid.add_child(b)
		var m := MarginContainer.new()
		m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side_name in ["left", "right", "top", "bottom"]:
			m.add_theme_constant_override("margin_" + side_name, 12)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(m)
		var box := _entry(a.name, a.desc, C_HEAD, 20)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var stats := HBoxContainer.new()
		stats.add_theme_constant_override("separation", 12)
		for k in ["int", "psy", "fys", "mot"]:
			var st := _heading_label("%s %d" % [game.world.ATTRS[k].name, int(a.attrs[k])], Color(Game.ATTR_COLORS[k]), 15)
			st.autowrap_mode = TextServer.AUTOWRAP_OFF
			stats.add_child(st)
		box.add_child(stats)
		for c in box.get_children() + stats.get_children():
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_child(box)
	_modal_text("판정: 2d6 + 기술 레벨 ≥ 난이도. 흰 판정은 기술이 오르면 재시도 가능, ● 붉은 판정은 단 한 번.", C_DIM, 14)


func _start_new(i: int) -> void:
	game.new_game(i)
	rendered_serial = 0
	_close_modal()
	title.hide()
	_refresh()


# ---------- 첫화면 ----------
func _show_title() -> void:
	_close_modal()
	title.refresh(game.has_game() or FileAccess.file_exists(Game.SAVE_PATH))
	title.show()
	audio.play_title()


## 이어하기: 진행 중인 판이 있으면 그대로 돌아가고, 없으면 저장한 판을 불러온다.
func _on_continue() -> void:
	if not game.has_game():
		_on_load()
		if not game.has_game():
			return
	title.hide()
	_close_modal()
	_update_atmosphere()


func _open_settings() -> void:
	_open_modal(1)
	_modal_title("설정")
	_setting_slider("소리 크기", settings.master, 0.0, 1.0, func(v):
		settings.master = v
		audio.set_volumes(settings.master, settings.music))
	_setting_slider("음악 크기", settings.music, 0.0, 1.0, func(v):
		settings.music = v
		audio.set_volumes(settings.master, settings.music))
	_setting_slider("글자 나오는 속도", settings.text_speed, 30.0, 400.0, func(v): settings.text_speed = v)
	_setting_slider("창백 효과 세기", settings.pale_strength, 0.0, 1.5, func(v):
		settings.pale_strength = v
		if game.has_game():
			_update_atmosphere())
	var lite := CheckButton.new()
	lite.text = "가벼운 화면 (저사양·웹에서 느릴 때)"
	lite.button_pressed = settings.lite
	lite.add_theme_font_override("font", font_bold)
	lite.add_theme_color_override("font_color", C_HEAD)
	lite.toggled.connect(func(on):
		settings.lite = on
		settings.save()
		_update_overlay_visibility()
		for b in backgrounds:
			if b.material != null and on:
				b.material = null
		if not on and VISTAS.has(bg_id):
			backgrounds[bg_active].material = vista_fx)
	modal_body.add_child(lite)
	var mute := CheckButton.new()
	mute.text = "소리 끄기"
	mute.button_pressed = settings.muted
	mute.add_theme_font_override("font", font_bold)
	mute.add_theme_color_override("font_color", C_HEAD)
	mute.toggled.connect(func(on):
		settings.muted = on
		audio.set_muted(on)
		settings.save())
	modal_body.add_child(mute)
	_modal_text("설정은 자동으로 보관됩니다.", C_DIM, 14)


func _setting_slider(label: String, value: float, lo: float, hi: float, on_change: Callable) -> void:
	modal_body.add_child(_heading_label(label, C_HEAD, 17))
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = (hi - lo) / 100.0
	s.value = value
	s.custom_minimum_size = Vector2(500, 28)
	s.value_changed.connect(func(v):
		on_change.call(v)
		settings.save())
	modal_body.add_child(s)


func _open_credits() -> void:
	_open_modal(1)
	_modal_title("만든이들")
	for line in [
		["기획 · 이야기 방향", "dkskhjs"],
		["글 · 프로그람 · 음악 합성", "Claude (Anthropic)"],
		["인물 · 배경 그림", "Gemini로 생성, 기획자 감수"],
		["압록강 사진", "「North Korea and Yalu River」 — Tyler from Shanghai, China (Wikimedia Commons) · CC BY 2.0\n흐림·어둡게 가공함 — creativecommons.org/licenses/by/2.0"],
		["음악 · 소리", "모두 합성음 — tools/make_audio.py, tools/make_music.py"],
		["글꼴", "나눔명조 (SIL Open Font License 1.1)"],
		["엔진", "Godot Engine (MIT 허가)"],
	]:
		modal_body.add_child(_heading_label(line[0], C_HEAD, 15))
		_modal_text(line[1], C_INK, 18)
	_modal_text("\n이 놀이는 꾸며낸 이야기이며, 실존 인물·단체와 관계없습니다.", C_DIM, 13)


func _open_sheet() -> void:
	if not game.has_game():
		return
	_open_modal()
	_modal_title(_hero_title())
	_modal_text("기술 점수: %d · 각 기술은 속성 값만큼 추가로 올릴 수 있다." % int(game.S.sp))
	_dossier_card()
	if game.S.names.size() > 0:
		_modal_heading("수첩 — 기억한 이름")
		_modal_text(" · ".join(game.S.names), C_INK, 15)
	var items := game.items_list()
	if items.size() > 0:
		_modal_heading("소지품")
		for it in items:
			var row := HBoxContainer.new()
			modal_body.add_child(row)
			row.add_child(_entry(it.name + ((" ×%d" % it.count) if it.count > 1 else ""),
				it.desc + ((" · " + it.effect) if it.effect != "" else ""), C_HEAD, 16))
			if it.usable:
				var b := Button.new()
				b.text = "먹는다"
				var id: String = it.id
				b.pressed.connect(func():
					game.use_item(id)
					_open_sheet()
					_refresh())
				row.add_child(b)
	for section in game.sheet_extras():
		_modal_heading(section[0])
		for line in section[1]:
			var parts: PackedStringArray = line.split("\n", true, 1)
			modal_body.add_child(_entry(parts[0], parts[1] if parts.size() > 1 else "", C_INK, 16))
	_modal_heading("기술")
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
		head.add_theme_font_override("font", font_bold)
		head.add_theme_font_size_override("font_size", 21)
		col.add_child(head)
		for k in game.world.SKILLS:
			var sk: Dictionary = game.world.SKILLS[k]
			if sk.attr != a:
				continue
			var row := HBoxContainer.new()
			col.add_child(row)
			var tb := game.thought_bonus(k)
			var ib := game.item_bonus(k)
			var extra := ""
			if tb != 0:
				extra += " (%+d 사상)" % tb
			if ib != 0:
				extra += " (%+d 장비)" % ib
			row.add_child(_entry("%s %d%s" % [sk.name, game.level(k), extra], sk.desc, Color(Game.ATTR_COLORS[a]).lightened(0.15), 16))
			if int(game.S.sp) > 0 and int(game.S.bought.get(k, 0)) < int(game.S.attrs[a]):
				var b := Button.new()
				b.text = "+"
				b.pressed.connect(func():
					game.buy(k)
					_open_sheet()
					_refresh())
				row.add_child(b)


## 주인공을 부르는 이름: 스스로 소리 내어 말해 보기 전까지는 하얗다.
func _hero_title() -> String:
	if game.has_game() and game.flag("said_own_name"):
		return "보위원 소좌 한은석"
	return "보위원 소좌 [이름 없음]"


## 13국 신상 카드: 단서를 모을수록 한 줄씩 채워진다. 문장은 주인공의 추측이라 틀릴 수 있다.
func _dossier_card() -> void:
	_modal_heading("13국 신상 카드")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	modal_body.add_child(grid)
	for row in dossier.rows:
		var text := ""
		if row.has("items"):
			var lines := []
			for it in row.items:
				if game.eval_cond(it["if"]):
					lines.append(it.text)
			if lines.is_empty():
				continue
			text = "\n".join(lines)
		for st in row.get("steps", []):
			if game.eval_cond(st["if"]):
				text = st.text
		var lab := _heading_label(row.label, C_HEAD, 15)
		lab.custom_minimum_size.x = 64
		grid.add_child(lab)
		var d := _desc_label(text, 15)
		d.custom_minimum_size.x = 640
		if text != "?" and not text.begins_with("[하얗다]"):
			d.add_theme_color_override("font_color", C_INK)
		grid.add_child(d)


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
		_modal_heading("내면화된 사상")
		for id in t.done:
			_thought_card(id, "done")
	if t.active == "" and t.known.is_empty() and t.done.is_empty():
		_modal_text("아직 품은 사상이 없다. 생각은 위험한 곳에서 온다.", C_INK)


## 명부: 사람(세대별 이름) 장과 약도 장. 약도는 LedgerMap이 그린다.
func _open_ledger(tab: String) -> void:
	if not game.has_game() or game.item_count("ledger") <= 0:
		return
	ledger_tab = tab
	_open_modal()
	_modal_title("청수리 인민반 명부")
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	modal_body.add_child(tabs)
	var pages := [["people", "사람"]]
	for m in ledger_data.maps:
		if not m.has("show_if") or game.eval_cond(m.show_if):
			pages.append([m.id, m.title])
	for pg in pages:
		var b := Button.new()
		b.text = pg[1]
		b.add_theme_font_size_override("font_size", 16)
		if pg[0] == tab:
			b.add_theme_font_override("font", font_bold)
			b.add_theme_color_override("font_color", C_HEAD)
		b.pressed.connect(_open_ledger.bind(pg[0]))
		tabs.add_child(b)
	if tab == "people":
		_ledger_people()
		return
	for m in ledger_data.maps:
		if m.id == tab:
			var reach := _ledger_reachable(m)
			var legend := "● 가 본 곳 · ○ 아는 곳 · 붉은 점 지금 있는 곳 · 하얀 자리 창백"
			if not reach.is_empty():
				legend += " · 붉은 테두리를 누르면 그리로 간다"
			_modal_text(m.note + "   " + legend, C_DIM, 13)
			var map := LedgerMap.new()
			map.custom_minimum_size = Vector2(730, 325)
			modal_body.add_child(map)
			map.setup(game, m, ledger_data.households, font_regular, reach)
			map.place_clicked.connect(func(id: String):
				_close_modal()
				game_choose(reach[id]))
			map.house_clicked.connect(_ledger_open_line)


## 약도에서 바로 갈 수 있는 곳: 지금 장면의 선택지 가운데 판정 없이 그 장소로 가는 것.
## 이야기의 조건(req/not/once)을 그대로 따르므로, 약도는 길을 새로 내지 않고 이미 난 길을 보여줄 뿐이다.
func _ledger_reachable(m: Dictionary) -> Dictionary:
	var out := {}
	if str(game.S.node).begins_with("lg_") or game.node().get("ending", false):
		return out
	var here: String = game.node().scene
	for st in game.visible_options():
		var o: Dictionary = st.opt
		if st.locked or o.has("check") or not o.has("go") or not game.story.has(o.go):
			continue
		var target: String = game.story[o.go].scene
		for pl in m.places:
			if out.has(pl.id):
				continue
			var matches := func(sc: String) -> bool: return sc != "" and target.begins_with(sc)
			var is_here := func(sc: String) -> bool: return here.begins_with(sc)
			if pl.scenes.any(matches) and not pl.scenes.any(is_here):
				out[pl.id] = st
	return out


## 지금 청수리 안에 있는가 (4일째까지). 하얘진 집 앞에서 이름을 부를 수 있는지 가른다.
func _in_cheongsu() -> bool:
	if int(game.S.day) > 4:
		return false
	var n: String = game.S.node
	var scene: String = game.story[game.S.get("ledger_from", n)].scene if n.begins_with("lg_") else game.node().scene
	for m in ledger_data.maps:
		if m.id == "cheongsu":
			for pl in m.places:
				for sc in pl.scenes:
					if scene.begins_with(sc):
						return true
	return false


func _ledger_open_line(index: int) -> void:
	if game.node().get("ending", false):
		return
	_close_modal()
	game.open_ledger("lg_" + ledger_data.households[index].id, _in_cheongsu())
	_refresh()


func _ledger_people() -> void:
	_modal_text("48세대. 주소 순서대로. 네가 아는 집만 옮겨 적었다.", C_DIM, 14)
	var listed := {}
	for i in ledger_data.households.size():
		var hh: Dictionary = ledger_data.households[i]
		if hh.has("known_if") and not game.eval_cond(hh.known_if):
			continue
		if hh.get("erased", false):
			_ledger_erased_line(i, hh)
			for person in hh.people:
				listed[person.name] = true
			continue
		modal_body.add_child(_heading_label("%s · %s" % [hh.addr, hh.head], C_HEAD, 17))
		for person in hh.people:
			listed[person.name] = true
			var white: bool = person.has("white_if") and game.eval_cond(person.white_if)
			var l := _desc_label(("　　 —  (하얗다)" if white else "　　 %s — %s" % [person.name, person.note]), 15)
			if not white and game.has_name(person.name):
				l.add_theme_color_override("font_color", C_INK)
			modal_body.add_child(l)
	var others := []
	for nm in game.S.names:
		if not listed.has(nm):
			others.append(nm)
	_modal_heading("빈 장에 적은 이름")
	if others.is_empty():
		_modal_text("아직 없다. 불러야 적을 수 있다.", C_DIM, 15)
	else:
		_modal_text(" · ".join(others), C_INK, 16)


## 하얘진 집 한 줄: 「이사 감」 → 이름을 적음 → 그 집 앞에서 불러 돌아옴. 줄을 누르면 명부 장면(lg_*)이 열린다.
func _ledger_erased_line(i: int, hh: Dictionary) -> void:
	var called := game.eval_cond(hh.called_if)
	var named := game.eval_cond(hh.name_if)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var head := _heading_label("%s · %s" % [hh.addr, hh.head if named else "　　　"], C_HEAD if called else C_DIM, 17)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(head)
	var can_open: bool = not called and not game.node().get("ending", false)
	if can_open:
		var b := Button.new()
		b.text = "이 줄을 들여다본다"
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(_ledger_open_line.bind(i))
		row.add_child(b)
	modal_body.add_child(row)
	var p: Dictionary = hh.people[0]
	var desc := ""
	if called:
		desc = "　　 %s — %s. 그 집 앞에서 불렀다. 잉크가 다시 고였다." % [p.name, p.note]
	elif named:
		desc = "　　 %s — %s. 연필로 적었다. 아직 그 집 앞에서 부르지 않았다." % [p.name, p.note]
	elif game.eval_cond(hh.smudged_if):
		desc = "　　 「이사 감」. 홈이 번졌다. 박순녀만 이 이름을 안다."
	else:
		desc = "　　 볼펜 자국의 홈만 남고 잉크가 없다. 옆에 박순녀의 글씨: 「이사 감」"
	var l := _desc_label(desc, 14)
	if called:
		l.add_theme_color_override("font_color", C_INK)
	modal_body.add_child(l)


func _thought_card(id: String, state: String) -> void:
	var th: Dictionary = game.world.THOUGHTS[id]
	var bonus := []
	for k in th.bonus:
		bonus.append("%s %+d" % [game.world.SKILLS[k].name, int(th.bonus[k])])
	var gap := Control.new()
	gap.custom_minimum_size.y = 4
	modal_body.add_child(gap)
	modal_body.add_child(_heading_label("「%s」" % th.name, C_HEAD, 18))
	_modal_text(th.a if state == "done" else th.q, C_INK, 15)
	_modal_text("효과: %s · 내면화 %d턴" % [", ".join(bonus), int(th.time)], C_DIM, 13)
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
	game.sys("— 보관되였습니다 —" if game.save_game() else "— 보관하지 못했습니다 —")
	_render_log()


func _on_load() -> void:
	if game.load_game():
		rendered_serial = 0
		instant_log = true
		game.sys("— 보관된 놀이를 불러왔습니다 —")
		_close_modal()
		_refresh()
	elif game.has_game():
		game.sys("— 보관된 놀이가 없습니다 —")
		_render_log()
