## 첫 화면(차림표). 새놀이 · 이어하기 · 설정 · 만든이들 · 끝내기.
class_name TitleScreen
extends Control

signal new_game
signal continue_game
signal open_settings
signal open_credits
signal quit_game

const C_RED := Color("#b8302b")
const C_INK := Color("#e4dccd")
const C_DIM := Color("#8f877a")

var continue_btn: Button
var quit_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists("res://art/scenes/square_pale.webp"):
		bg.texture = load("res://art/scenes/square_pale.webp")
	add_child(bg)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.06, 0.055, 0.05, 0.78)
	add_child(shade)
	# 왼쪽의 붉은 띠: 선전 포스터의 깃발 자리
	var band := ColorRect.new()
	band.color = C_RED
	band.anchor_bottom = 1.0
	band.offset_left = 80
	band.offset_right = 92
	add_child(band)

	var col := VBoxContainer.new()
	col.position = Vector2(140, 150)
	col.add_theme_constant_override("separation", 6)
	add_child(col)
	var caption := Label.new()
	caption.text = "량강도 백수군 · 주체 ??년"
	caption.add_theme_color_override("font_color", C_DIM)
	caption.add_theme_font_size_override("font_size", 18)
	col.add_child(caption)
	var title := Label.new()
	title.text = "창백한 청수리"
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", C_INK)
	col.add_child(title)
	var sub := Label.new()
	sub.text = "압록강 너머가 사라졌다. 그리고 당신의 이름이 지워지고 있다."
	sub.add_theme_color_override("font_color", C_DIM)
	sub.add_theme_font_size_override("font_size", 18)
	col.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size.y = 48
	col.add_child(gap)

	_menu(col, "새놀이", new_game.emit)
	continue_btn = _menu(col, "이어하기", continue_game.emit)
	_menu(col, "설정", open_settings.emit)
	_menu(col, "만든이들", open_credits.emit)
	quit_btn = _menu(col, "끝내기", quit_game.emit)
	quit_btn.visible = not OS.has_feature("web")   # 웹에서는 창을 닫을 수 없다

	var note := Label.new()
	note.text = "※ 이 놀이는 꾸며낸 이야기이며, 실존 인물·단체와 관계없습니다."
	note.add_theme_color_override("font_color", C_DIM)
	note.add_theme_font_size_override("font_size", 13)
	note.anchor_top = 1.0
	note.anchor_bottom = 1.0
	note.offset_left = 140
	note.offset_top = -48
	add_child(note)


func _menu(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = "▸  " + text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.flat = true
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_color_override("font_color", C_INK)
	b.add_theme_color_override("font_hover_color", C_RED.lightened(0.2))
	b.add_theme_color_override("font_focus_color", C_RED.lightened(0.2))
	b.add_theme_color_override("font_disabled_color", C_DIM.darkened(0.3))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


## 이어할 판이 있는지에 따라 '이어하기'를 켜고 끈다.
func refresh(can_continue: bool) -> void:
	continue_btn.disabled = not can_continue
