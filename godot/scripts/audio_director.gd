## 장면에 맞는 환경음과 시간대별 음악을 교차 재생하고, 게임 이벤트에 효과음을 붙인다.
## 소리는 전부 tools/make_audio.py와 tools/make_music.py로 합성한 것이다.
class_name AudioDirector
extends Node

const FADE := 2.5
const AMB_DB := {
	"square": -6.0, "rally": -4.0, "radio": -3.0, "room": -6.0,
	"night": -10.0, "wind": -10.0, "silence": -80.0,
}
const MUSIC_DB := -11.0
const HOPEFUL_ENDINGS := ["end_truth", "end_names", "end_wake"]
## 창백 드론: 노출이 없으면 거의 안 들리고, 경계에서는 크게.
const PALE_MIN_DB := -40.0
const PALE_MAX_DB := -9.0
const SFX := {
	"roll_ok": ["sfx_success"], "roll_no": ["sfx_fail"],
	"thought_new": ["sfx_thought"], "thought_done": ["sfx_thought"],
	"pale_up": ["sfx_pale"], "pale_down": ["sfx_name"], "name": ["sfx_name"],
}

var muted := false
var music_gain_db := 0.0   # 설정의 음악 크기
var _amb := Layer.new()
var _music := Layer.new()
var _pale: AudioStreamPlayer
var _sfx: Array[AudioStreamPlayer] = []
var _streams := {}


func _ready() -> void:
	_amb.setup(self)
	_music.setup(self)
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
	if "궐기대회" in scene or "기념비 광장" in scene:
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


## 디스코 엘리시움처럼 시간대마다 같은 주제의 다른 편곡이 흐른다.
## 확성기·라디오에서 이미 음악이 나오는 곳에서는 끈다.
static func music_for(scene: String, node_id: String, day: int, ending: bool, minutes: int) -> String:
	if ending:
		return "hope" if node_id in HOPEFUL_ENDINGS else "pale"
	var amb := ambience_for(scene, day, ending)
	if amb in ["square", "rally", "radio"]:
		return "silence"
	if "압록강" in scene or "창백" in scene or "경계" in scene:
		return "pale"
	if day >= 3 and minutes >= 17 * 60:
		return "pale"
	if "밤" in scene or "어둠" in scene or minutes >= 21 * 60:
		return "night"
	if minutes < 11 * 60:
		return "morning"
	if minutes < 17 * 60:
		return "day"
	return "evening"


## 창백 앞에 서 있을수록 드론이 커진다.
static func edge_for(scene: String) -> float:
	if "창백" in scene or "경계" in scene:
		return 1.0
	if "압록강" in scene:
		return 0.6
	return 0.0


func update(scene: String, node_id: String, day: int, ending: bool, pale: float, minutes: int) -> void:
	var amb := ambience_for(scene, day, ending)
	_amb.switch(amb, _load("amb_" + amb, true) if amb != "silence" else null, AMB_DB.get(amb, -80.0))
	var mus := music_for(scene, node_id, day, ending, minutes)
	_music.switch(mus, _load("mus_" + mus, true) if mus != "silence" else null, MUSIC_DB + music_gain_db)
	var edge := edge_for(scene)
	var level := clampf(pale + edge * 0.8 + (0.7 if ending else 0.0), 0.0, 1.0)
	var target := lerpf(PALE_MIN_DB, PALE_MAX_DB, sqrt(level))
	create_tween().tween_property(_pale, "volume_db", target, FADE)


## 두 플레이어를 번갈아 쓰며 교차 페이드하는 소리 층.
class Layer:
	var players: Array[AudioStreamPlayer] = []
	var active := 0
	var current := ""
	var owner: Node

	func setup(o: Node) -> void:
		owner = o
		for i in 2:
			var p := AudioStreamPlayer.new()
			p.volume_db = -80.0
			o.add_child(p)
			players.append(p)

	func switch(key: String, stream: AudioStream, db: float) -> void:
		if key == current:
			return
		current = key
		var old := players[active]
		active = 1 - active
		var nxt := players[active]
		var tw := owner.create_tween().set_parallel()
		tw.tween_property(old, "volume_db", -80.0, FADE)
		tw.chain().tween_callback(old.stop)
		if stream != null:
			nxt.stream = stream
			nxt.volume_db = -80.0
			nxt.play()
			owner.create_tween().tween_property(nxt, "volume_db", db, FADE)


## 첫 화면: 환경음 없이 메인 테마만.
func play_title() -> void:
	_amb.switch("silence", null, -80.0)
	_music.switch("morning", _load("mus_morning", true), MUSIC_DB + music_gain_db)
	create_tween().tween_property(_pale, "volume_db", PALE_MIN_DB, FADE)


func set_volumes(master: float, music: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master, 0.0001)))
	music_gain_db = linear_to_db(maxf(music, 0.0001))
	var p: AudioStreamPlayer = _music.players[_music.active]
	if _music.current != "silence" and _music.current != "":
		p.volume_db = MUSIC_DB + music_gain_db


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

