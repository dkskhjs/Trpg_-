## 장면에 맞는 배경음을 교차 재생하고, 게임 이벤트에 효과음을 붙인다.
## 소리는 전부 tools/make_audio.py로 합성한 것이다.
class_name AudioDirector
extends Node

const FADE := 2.5
const AMB_DB := {
	"square": -6.0, "rally": -4.0, "radio": -3.0, "room": -6.0,
	"night": -10.0, "wind": -10.0, "silence": -80.0,
}
## 창백 드론: 노출이 없으면 거의 안 들리고, 경계에서는 크게.
const PALE_MIN_DB := -40.0
const PALE_MAX_DB := -9.0
const SFX := {
	"roll_ok": ["sfx_success"], "roll_no": ["sfx_fail"],
	"thought_new": ["sfx_thought"], "thought_done": ["sfx_thought"],
	"pale_up": ["sfx_pale"], "pale_down": ["sfx_name"], "name": ["sfx_name"],
}

var muted := false
var _amb: Array[AudioStreamPlayer] = []
var _active := 0
var _current := ""
var _pale: AudioStreamPlayer
var _sfx: Array[AudioStreamPlayer] = []
var _streams := {}


func _ready() -> void:
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		_amb.append(p)
	_pale = AudioStreamPlayer.new()
	_pale.stream = _load("amb_pale", true)
	_pale.volume_db = PALE_MIN_DB
	add_child(_pale)
	_pale.play()
	for i in 6:
		var s := AudioStreamPlayer.new()
		add_child(s)
		_sfx.append(s)


func _load(name: String, loop: bool) -> AudioStream:
	if not _streams.has(name):
		var s: AudioStreamOggVorbis = load("res://audio/%s.ogg" % name)
		s.loop = loop
		_streams[name] = s
	return _streams[name]


## 장면 이름과 날짜로 배경음을 고른다. 3일째에는 확성기마저 하얘져 광장이 조용하다.
static func ambience_for(scene: String, day: int, ending: bool) -> String:
	if ending:
		return "silence"
	if "궐기대회" in scene:
		return "rally"
	if "관측소" in scene:
		return "radio"
	if "압록강" in scene or "창백" in scene or "경계" in scene:
		return "silence"
	if "밤" in scene or "어둠" in scene:
		return "night"
	if "초대소" in scene:
		return "room" if day < 3 else "night"
	if "광장" in scene or "군용 트럭" in scene or "박순녀" in scene:
		return "square" if day < 3 else "wind"
	return "wind"


## 창백 앞에 서 있을수록 드론이 커진다.
static func edge_for(scene: String) -> float:
	if "창백" in scene or "경계" in scene:
		return 1.0
	if "압록강" in scene:
		return 0.6
	return 0.0


func update(scene: String, day: int, ending: bool, pale: float) -> void:
	var key := ambience_for(scene, day, ending)
	if key != _current:
		_crossfade(key)
	var edge := edge_for(scene)
	var level := clampf(pale + edge * 0.8 + (0.7 if ending else 0.0), 0.0, 1.0)
	var target := lerpf(PALE_MIN_DB, PALE_MAX_DB, sqrt(level))
	create_tween().tween_property(_pale, "volume_db", target, FADE)


func _crossfade(key: String) -> void:
	_current = key
	var old := _amb[_active]
	_active = 1 - _active
	var nxt := _amb[_active]
	var tw := create_tween().set_parallel()
	tw.tween_property(old, "volume_db", -80.0, FADE)
	if key != "silence":
		nxt.stream = _load("amb_" + key, true)
		nxt.volume_db = -80.0
		nxt.play()
		tw.tween_property(nxt, "volume_db", AMB_DB[key], FADE)


func play_events(events: Array) -> void:
	var delay := 0.0
	for e in events:
		for name in SFX.get(e, []):
			_play_sfx(name, delay)
			delay += 0.15


func click() -> void:
	_play_sfx("sfx_click", 0.0)


func _play_sfx(name: String, delay: float) -> void:
	var p := _sfx[0]
	for s in _sfx:
		if not s.playing:
			p = s
			break
	p.stream = _load(name, false)
	p.volume_db = -4.0
	if delay > 0.0:
		get_tree().create_timer(delay).timeout.connect(p.play)
	else:
		p.play()


func set_muted(m: bool) -> void:
	muted = m
	AudioServer.set_bus_mute(0, m)

