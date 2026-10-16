class_name Balance
extends RefCounted
## 数値の置き場。遊んで直すところは、ここに集める。
## SRD の数値(HP、ダメージ、DC)はそのまま使い、リアルタイムに直す係数だけをここで持つ。

const CELL := 32                       # 1マス(5フィート)の画素数
const FT_TO_PX := 4.0                  # 移動速度: 1フィート/ラウンド → 画素/秒(30フィートで120)
const MAX_FLOOR := 18                  # 書き出してある階の数(10の層が、1〜3階ずつのグループ。tools/export-floors.mjs の LAYERS)
const NIGHTS := 7                      # 書き出してある夜の数(7夜で一巡。世界の「節」と同じ周期)
const TAX_RATE := 0.3                  # 燐晶税(都市GM資料)

# 仲間(キャラクター)
const HERO_RADIUS := 9.0
const HERO_SPEED := 150.0
const ROLL_SPEED := 340.0
const ROLL_TIME := 0.22
const ROLL_COOLDOWN := 0.8
const LIGHT_RADIUS := 7                # 灯りの半径(マス)
const MAX_PARTY := 4
const START_PARTY := 2                 # 始めの人数。残りは宿屋の酒場で加える

# 体当たり(ハイドライド式)の押し合い。魔物は触れている間、一定間隔でダメージを与える(仲間は通常攻撃で殴る)
static var BUMP_TICK := 0.25                # ダメージが入る間隔(秒)
static var BUMP_SCALE := 0.55               # クラスの体当たり火力にかける係数
static var PUSH_SCALE := 2.2                # 押し合いの速さにかける係数
static var HP_FLOOR := 0.35                 # HPが0に近いときの押す力の下限(これに 0.65×HP割合 を足す)
static var HP_SCALE := 1.5                  # キャラクターの最大HPにかける係数
static var AC_REDUCTION := 0.035            # 防御1点あたりの軽減率
const GUARD_MASS := 2.0                # 構え(Ctrl)の間、押されにくくなる倍率

# 通常攻撃(ボタンで正面へ一撃)。体当たりの自動攻撃の代わり
static var ATTACK_SCALE := 1.3              # 一撃のダメージ = 体当たり火力 × 待ち時間 × これ
static var ATTACK_CD := 0.7                 # 次に振れるまでの待ち時間(秒)
const ATTACK_REACH := 22.0             # 体の縁から届く距離(画素)
const ATTACK_ARC := 70.0               # 正面から左右に届く角度(度)
const ATTACK_KNOCK := 140.0            # 当たった相手を押し返す強さ

# 魔物
static var ENEMY_SPEED_SCALE := 0.85        # 魔物の移動の速さにかける
static var ENEMY_HP_SCALE := 1.5            # 魔物の最大HPにかける(SRD の hp × これ)

# SRD の「1ラウンド6秒」を、アクションの手数に直す係数
static var ENEMY_DMG_SCALE := 0.4           # 敵の一撃にかける(体当たりでは、これを攻撃間隔で割った毎秒のダメージにする)
static var TRAP_DMG_SCALE := 0.6            # 罠のダメージにかける
static var ENEMY_ATTACK_INTERVAL := 1.6     # 敵の攻撃の間隔(秒)

# 燐晶と自生物(docs/dungeon-scale.md、docs/items-and-forage.md)
const TAX_NOTE := "燐晶だけが課税"
static var CRYSTAL_SCALE := 0.3             # 層に置く・魔物や遺体が落とす燐晶の量(kg)にかける。1.0 で、地図生成器の宝の量そのまま
static var FORAGE_CELLS := 70.0             # 自生物は、歩ける床(部屋と通路)この数のマスにつき1つ

# 迷宮の中の時間(分)。太陽と月で見せる。夜になると、起きている一行は吐息に呑まれ、どこかの部屋へ放り出される
const DIVE_START_MIN := 7 * 60          # 潜り始めの時刻
const NIGHT_MIN := 20 * 60              # 日が落ちる時刻
const DAWN_MIN := 6 * 60                # 夜が明ける時刻
static var CLOCK_RATE := 1.0                # 起きている間、実時間1秒で進む分
static var REST_RATE := 50.0                # 休んでいる間、実時間1秒で進む分
const REST_HOURS := [6, 8]             # 休むと、この幅の時間(ランダム)で目を覚ます
# ワンダリング・モンスター。10分ごとに出現を振る
const WANDER_EVERY := 10.0
static var WANDER_CHANCE := 1.0 / 12.0      # 起きているとき
static var REST_WANDER_CHANCE := 0.012      # 休んでいるとき(7時間でおよそ4割)
const WANDER_MAX := 3                  # 層に同時にいる、ワンダリングの群れの上限
const SURPRISE_TIME := 1.5             # 寝込みを襲われたとき、動けない秒

## 闘技場で、実行中に動かして調整できる係数。[初期値, 最小, 最大, 説明]
const TUNABLE := {
	"ENEMY_DMG_SCALE": [0.4, 0.05, 1.5, "敵の攻撃の係数(大きいほど痛い)"],
	"ENEMY_ATTACK_INTERVAL": [1.6, 0.4, 4.0, "敵の攻撃の間隔・秒(大きいほど痛くない)"],
	"BUMP_SCALE": [0.55, 0.15, 1.5, "仲間の火力の係数(通常攻撃の元)"],
	"ATTACK_SCALE": [1.3, 0.3, 3.0, "通常攻撃の一撃の係数"],
	"ATTACK_CD": [0.7, 0.2, 2.0, "通常攻撃の待ち時間・秒"],
	"ENEMY_SPEED_SCALE": [0.85, 0.4, 1.5, "魔物の移動の速さの係数"],
	"ENEMY_HP_SCALE": [1.5, 0.5, 4.0, "魔物の最大HPの係数(次に出る魔物から)"],
	"PUSH_SCALE": [2.2, 0.5, 5.0, "押し合いの強さの係数"],
	"HP_SCALE": [1.5, 0.5, 3.0, "仲間の最大HPの係数"],
	"HP_FLOOR": [0.35, 0.0, 0.9, "HPが減っても残る押す力の下限"],
	"AC_REDUCTION": [0.035, 0.0, 0.08, "防御1点あたりの軽減率"],
	"TRAP_DMG_SCALE": [0.6, 0.1, 1.5, "罠のダメージの係数"],
}

static func tune_get(key: String) -> float:
	match key:
		"ENEMY_DMG_SCALE": return ENEMY_DMG_SCALE
		"ENEMY_ATTACK_INTERVAL": return ENEMY_ATTACK_INTERVAL
		"BUMP_SCALE": return BUMP_SCALE
		"PUSH_SCALE": return PUSH_SCALE
		"HP_SCALE": return HP_SCALE
		"HP_FLOOR": return HP_FLOOR
		"AC_REDUCTION": return AC_REDUCTION
		"TRAP_DMG_SCALE": return TRAP_DMG_SCALE
		"ENEMY_HP_SCALE": return ENEMY_HP_SCALE
		"ENEMY_SPEED_SCALE": return ENEMY_SPEED_SCALE
		"ATTACK_CD": return ATTACK_CD
		"ATTACK_SCALE": return ATTACK_SCALE
	return 0.0

static func tune_set(key: String, v: float) -> void:
	match key:
		"ENEMY_DMG_SCALE": ENEMY_DMG_SCALE = v
		"ENEMY_ATTACK_INTERVAL": ENEMY_ATTACK_INTERVAL = v
		"BUMP_SCALE": BUMP_SCALE = v
		"PUSH_SCALE": PUSH_SCALE = v
		"HP_SCALE": HP_SCALE = v
		"HP_FLOOR": HP_FLOOR = v
		"AC_REDUCTION": AC_REDUCTION = v
		"TRAP_DMG_SCALE": TRAP_DMG_SCALE = v
		"ENEMY_HP_SCALE": ENEMY_HP_SCALE = v
		"ENEMY_SPEED_SCALE": ENEMY_SPEED_SCALE = v
		"ATTACK_CD": ATTACK_CD = v
		"ATTACK_SCALE": ATTACK_SCALE = v

static func tune_reset() -> void:
	for k in TUNABLE:
		tune_set(k, float(TUNABLE[k][0]))

const XP_LEVELS := [0, 300, 900, 2700, 6500, 14000, 23000, 34000, 48000, 64000,
	85000, 100000, 120000, 140000, 165000, 195000, 225000, 265000, 305000, 355000]

# 平均ダメージ/ラウンド。攻撃の数値が取れなかった魔物の代用(脅威度から)
static func fallback_round_damage(cr: float) -> float:
	return 1.5 + cr * 6.0

static func level_for_xp(xp: int) -> int:
	var lv := 1
	for i in XP_LEVELS.size():
		if xp >= XP_LEVELS[i]:
			lv = i + 1
	return mini(lv, 20)

const SIZE_MASS := {"T": 0.4, "S": 0.7, "M": 1.0, "L": 1.8, "H": 2.8, "G": 4.0}
