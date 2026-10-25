## 놀이 설정. user://settings.cfg에 저장한다.
class_name Settings
extends RefCounted

const PATH := "user://settings.cfg"

var master := 0.9        # 소리 크기 (0~1)
var music := 0.8         # 음악 크기 (0~1)
var text_speed := 110.0  # 글자 나오는 속도 (초당 글자 수)
var pale_strength := 1.0 # 창백 효과 세기 (0~1.5)


static func load_or_default() -> Settings:
	var s := Settings.new()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		s.master = cfg.get_value("sound", "master", s.master)
		s.music = cfg.get_value("sound", "music", s.music)
		s.text_speed = cfg.get_value("display", "text_speed", s.text_speed)
		s.pale_strength = cfg.get_value("display", "pale_strength", s.pale_strength)
	return s


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("sound", "master", master)
	cfg.set_value("sound", "music", music)
	cfg.set_value("display", "text_speed", text_speed)
	cfg.set_value("display", "pale_strength", pale_strength)
	cfg.save(PATH)
