## 놀이 설정. user://settings.cfg에 저장한다.
class_name Settings
extends RefCounted

const PATH := "user://settings.cfg"

var master := 0.9        # 소리 크기 (0~1)
var music := 0.8         # 음악 크기 (0~1)
var text_speed := 110.0  # 글자 나오는 속도 (초당 글자 수)
var pale_strength := 1.0 # 창백 효과 세기 (0~1.5)
var muted := false       # 소리 끄기
var lite := false        # 가벼운 화면: 무거운 화면 효과를 끈다(저사양·웹)
var lite_auto_done := false  # 느려서 자동으로 한 번 바꿨다면 다시는 자동으로 바꾸지 않는다


static func load_or_default() -> Settings:
	var s := Settings.new()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		s.master = cfg.get_value("sound", "master", s.master)
		s.music = cfg.get_value("sound", "music", s.music)
		s.text_speed = cfg.get_value("display", "text_speed", s.text_speed)
		s.pale_strength = cfg.get_value("display", "pale_strength", s.pale_strength)
		s.muted = cfg.get_value("sound", "muted", s.muted)
		s.lite = cfg.get_value("display", "lite", s.lite)
		s.lite_auto_done = cfg.get_value("display", "lite_auto_done", s.lite_auto_done)
	return s


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("sound", "master", master)
	cfg.set_value("sound", "music", music)
	cfg.set_value("display", "text_speed", text_speed)
	cfg.set_value("display", "pale_strength", pale_strength)
	cfg.set_value("sound", "muted", muted)
	cfg.set_value("display", "lite", lite)
	cfg.set_value("display", "lite_auto_done", lite_auto_done)
	cfg.save(PATH)
