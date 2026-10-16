class_name GameSettings
extends RefCounted
## 遊び方の設定(user://settings.cfg)。ゲームの速さ、魔物の速さ、迷宮の画面の拡大。
## ゲームの速さは、迷宮の中だけ Engine.time_scale にかける(街やメニューは等速)。

const PATH := "user://settings.cfg"
## [名前, 係数]
const SPEEDS := [["遅い", 0.7], ["普通", 0.8], ["早い", 0.9], ["超早い", 1.0]]
const DEFAULT_SPEED := 1

## 魔物の歩く速さ。Balance.ENEMY_SPEED_SCALE にさらにかける。[名前, 係数]
const ENEMY_SPEEDS := [["遅い", 0.8], ["普通", 1.0], ["早い", 1.15], ["超早い", 1.3]]
const DEFAULT_ENEMY_SPEED := 1

## 迷宮の画面の拡大(カメラの倍率)。[名前, 倍率]
const ZOOMS := [["広く", 1.2], ["普通", 1.7], ["近く", 2.3]]
const DEFAULT_ZOOM := 1

## ミニマップ(右上。仲間のまわりだけ)の1マスの画素数。+ / - で替える
const MINIMAPS := [["広く", 2.0], ["普通", 3.0], ["近く", 4.0], ["もっと近く", 6.0]]
const DEFAULT_MINIMAP := 1
const MINIMAP_SIZE := Vector2(230, 160)

static var speed_index := DEFAULT_SPEED
static var minimap_index := DEFAULT_MINIMAP
static var zoom_index := DEFAULT_ZOOM
static var enemy_speed_index := DEFAULT_ENEMY_SPEED

static func load_settings() -> void:
	var cf := ConfigFile.new()
	speed_index = DEFAULT_SPEED
	enemy_speed_index = DEFAULT_ENEMY_SPEED
	zoom_index = DEFAULT_ZOOM
	minimap_index = DEFAULT_MINIMAP
	if cf.load(PATH) == OK:
		minimap_index = clampi(int(cf.get_value("game", "minimap", DEFAULT_MINIMAP)), 0, MINIMAPS.size() - 1)
		zoom_index = clampi(int(cf.get_value("game", "zoom", DEFAULT_ZOOM)), 0, ZOOMS.size() - 1)
		speed_index = clampi(int(cf.get_value("game", "speed", DEFAULT_SPEED)), 0, SPEEDS.size() - 1)
		enemy_speed_index = clampi(int(cf.get_value("game", "enemy_speed", DEFAULT_ENEMY_SPEED)), 0, ENEMY_SPEEDS.size() - 1)

static func save() -> void:
	var cf := ConfigFile.new()
	cf.load(PATH)
	cf.set_value("game", "speed", speed_index)
	cf.set_value("game", "enemy_speed", enemy_speed_index)
	cf.set_value("game", "zoom", zoom_index)
	cf.set_value("game", "minimap", minimap_index)
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

static func set_zoom(i: int) -> void:
	zoom_index = clampi(i, 0, ZOOMS.size() - 1)
	save()

static func zoom() -> float:
	return float(ZOOMS[zoom_index][1])

static func set_minimap(i: int) -> void:
	minimap_index = clampi(i, 0, MINIMAPS.size() - 1)
	save()

static func minimap_scale() -> float:
	return float(MINIMAPS[minimap_index][1])

static func minimap_name() -> String:
	return String(MINIMAPS[minimap_index][0])

static func zoom_name() -> String:
	return String(ZOOMS[zoom_index][0])

static func enemy_speed_name() -> String:
	return String(ENEMY_SPEEDS[enemy_speed_index][0])
