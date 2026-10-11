class_name GameSettings
extends RefCounted
## 遊び方の設定(user://settings.cfg)。いまはゲームの速さだけ。
## ゲームの速さは、迷宮の中だけ Engine.time_scale にかける(街やメニューは等速)。

const PATH := "user://settings.cfg"
## [名前, 係数]
const SPEEDS := [["遅い", 0.7], ["普通", 0.8], ["早い", 0.9], ["超早い", 1.0]]
const DEFAULT_SPEED := 1

static var speed_index := DEFAULT_SPEED

static func load_settings() -> void:
	var cf := ConfigFile.new()
	speed_index = DEFAULT_SPEED
	if cf.load(PATH) == OK:
		speed_index = clampi(int(cf.get_value("game", "speed", DEFAULT_SPEED)), 0, SPEEDS.size() - 1)

static func save() -> void:
	var cf := ConfigFile.new()
	cf.load(PATH)
	cf.set_value("game", "speed", speed_index)
	cf.save(PATH)

static func set_speed(i: int) -> void:
	speed_index = clampi(i, 0, SPEEDS.size() - 1)
	save()

static func speed() -> float:
	return float(SPEEDS[speed_index][1])

static func speed_name() -> String:
	return String(SPEEDS[speed_index][0])
