class_name GameSettings
extends RefCounted
## 遊び方の設定(user://settings.cfg)。ゲームの速さと、魔物の速さ。
## ゲームの速さは、迷宮の中だけ Engine.time_scale にかける(街やメニューは等速)。

const PATH := "user://settings.cfg"
## [名前, 係数]
const SPEEDS := [["遅い", 0.7], ["普通", 0.8], ["早い", 0.9], ["超早い", 1.0]]
const DEFAULT_SPEED := 1

## 魔物の歩く速さ。Balance.ENEMY_SPEED_SCALE にさらにかける。[名前, 係数]
const ENEMY_SPEEDS := [["遅い", 0.8], ["普通", 1.0], ["早い", 1.15], ["超早い", 1.3]]
const DEFAULT_ENEMY_SPEED := 1

static var speed_index := DEFAULT_SPEED
static var enemy_speed_index := DEFAULT_ENEMY_SPEED

static func load_settings() -> void:
	var cf := ConfigFile.new()
	speed_index = DEFAULT_SPEED
	enemy_speed_index = DEFAULT_ENEMY_SPEED
	if cf.load(PATH) == OK:
		speed_index = clampi(int(cf.get_value("game", "speed", DEFAULT_SPEED)), 0, SPEEDS.size() - 1)
		enemy_speed_index = clampi(int(cf.get_value("game", "enemy_speed", DEFAULT_ENEMY_SPEED)), 0, ENEMY_SPEEDS.size() - 1)

static func save() -> void:
	var cf := ConfigFile.new()
	cf.load(PATH)
	cf.set_value("game", "speed", speed_index)
	cf.set_value("game", "enemy_speed", enemy_speed_index)
	cf.save(PATH)

static func set_speed(i: int) -> void:
	speed_index = clampi(i, 0, SPEEDS.size() - 1)
	save()

static func speed() -> float:
	return float(SPEEDS[speed_index][1])

static func speed_name() -> String:
	return String(SPEEDS[speed_index][0])

static func set_enemy_speed(i: int) -> void:
	enemy_speed_index = clampi(i, 0, ENEMY_SPEEDS.size() - 1)
	save()

static func enemy_speed() -> float:
	return float(ENEMY_SPEEDS[enemy_speed_index][1])

static func enemy_speed_name() -> String:
	return String(ENEMY_SPEEDS[enemy_speed_index][0])
