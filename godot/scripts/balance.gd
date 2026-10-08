class_name Balance
extends RefCounted
## 数値の置き場。遊んで直すところは、ここに集める。
## SRD の数値(HP、ダメージ、DC)はそのまま使い、リアルタイムに直す係数だけをここで持つ。

const CELL := 32                       # 1マス(5フィート)の画素数
const FT_TO_PX := 4.0                  # 移動速度: 1フィート/ラウンド → 画素/秒(30フィートで120)
const MAX_FLOOR := 10                  # 書き出してある層の数
const NIGHTS := 14                     # 書き出してある夜の数。過ぎたら最初に戻る
const TAX_RATE := 0.3                  # 燐晶税(都市GM資料)

# プレイヤー
const PLAYER_RADIUS := 9.0
const PLAYER_SPEED := 150.0
const ROLL_SPEED := 340.0
const ROLL_TIME := 0.22
const ROLL_COOLDOWN := 0.7
const ATTACK_COOLDOWN := 0.5
const ATTACK_REACH := 46.0
const ATTACK_ARC_DEG := 75.0           # 正面から左右に何度まで当たるか
const LIGHT_RADIUS := 7                # 灯りの半径(マス)

# SRD の「1ラウンド6秒」を、アクションの手数に直す係数
const ENEMY_DMG_SCALE := 0.4           # 敵の一撃にかける
const TRAP_DMG_SCALE := 0.6            # 罠のダメージにかける
const ENEMY_ATTACK_INTERVAL := 1.6     # 敵の攻撃の間隔(秒)

const XP_LEVELS := [0, 300, 900, 2700, 6500, 14000, 23000, 34000, 48000, 64000,
	85000, 100000, 120000, 140000, 165000, 195000, 225000, 265000, 305000, 355000]

# 平均ダメージ/ラウンド。攻撃の数値が取れなかった魔物の代用(脅威度から)
static func fallback_round_damage(cr: float) -> float:
	return 1.5 + cr * 6.0

static func player_max_hp(lv: int) -> int:
	return 18 + 8 * (lv - 1)

static func player_damage(lv: int) -> float:
	return 4.5 + 1.2 * (lv - 1)

static func level_for_xp(xp: int) -> int:
	var lv := 1
	for i in XP_LEVELS.size():
		if xp >= XP_LEVELS[i]:
			lv = i + 1
	return mini(lv, 20)

# 受動〈知覚〉、判定の加値
static func passive_perception(lv: int) -> int:
	return 12 + (lv - 1) / 4

static func skill_bonus(lv: int) -> int:
	return 2 + lv / 2
